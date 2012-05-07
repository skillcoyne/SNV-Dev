require 'rubygems'
require 'fileutils'
require 'yaml'
require_relative 'lib/utils'

$script = "mdrAnalysis.R"
$config = "resources/gwa.config"

# Expected options:
# :input_path, :output_path, :k, :max
def write_scripts(opts = {})
  Dir.foreach(opts[:input_path]) do |entry|
    opts[:input_file] = "#{opts[:input_path]}/#{entry}"
    next unless File.extname(opts[:input_file]).eql? ".mdr"

    r_script = script_string(opts)
    filename = File.basename(opts[:input_file], ".mdr")

    File.open("#{opts[:output_path]}/#{filename}_#{$script}", 'w') { |f| f.write(r_script) }
    FileUtils.chmod(0776, "#{opts[:output_path]}/#{filename}_#{$script}")

    opts[:r_script] = "#{opts[:output_path]}/#{filename}_#{$script}"

    write_oar_file(opts)
  end
end

def write_oar_file(opts = {})

  filename = File.basename(opts[:input_file], ".mdr")

  oar_script =<<OAR
#!/bin/bash

TAKTUK_CONNECTOR='oarsh'

PROGNAME=Rscript #{opts[:r_script]}
NB_COMPUTING_RESOURCES=`wc -l $OAR_NODEFILE | cut -d " " -f 1`

echo "Resources used for execution of ${PROGNAME}"
cat $OAR_NODEFILE

kash -M ${OAR_NODEFILE} -- ${PROGNAME} \$TAKTUK_COUNT \$TAKTUK_RANK
OAR

  File.open("#{opts[:oar]}/oar_launcher.#{filename}.sh", 'w') { |f| f.write(oar_script) }
  FileUtils.chmod(0776, "#{opts[:oar]}/oar_launcher.#{filename}.sh")
end

def run_scripts(opts = {})
  script_path = opts['mdr.analysis.dir']
  cmd = "oarsub --notify \"#{opts['oar.notify']}\" core=#{opts['oar.core']},walltime=#{opts['oar.walltime']}"
  Dir.foreach(script_path) do |entry|
    next unless File.extname(entry).eql? ".sh"
    chr = File.basename(entry).sub(".sh", '')
    cmd = "#{cmd} -n MDR_#{chr} --stdout=MDR_#{chr}.out --stderr=MDR_#{chr}.err #{script_path}/#{entry}"
    puts "Starting #{cmd}"
#    system("sh #{script_path}/#{entry}")
  end
end


# Expected options:
# :input_file, :output_path, :k, :max
def script_string(opts = {})
  base = File.basename(opts[:input_file]).sub(".mdr", '')
  r_script =<<-R
#!/usr/bin/env
library(MDR)

nameModels<-function(model)
  {
  for(k in 1:length(model))
    {
    i=1
    for(snpI in model[[k]])
      {
      model[[k]][i]<-cols[[as.numeric(snpI)]]
      i<-i+1
      }
    }
  return(model)
  }

mdr_data<-read.table("#{opts[:input_file]}", header=TRUE)

#note if you don't slice the array you need to be aware of
# an off by 1 error in the nameModels function
cols<-colnames(mdr_data[2:#{opts[:max]}])
fit<-mdr.cv(mdr_data[1:#{opts[:max]}], K=#{opts[:k]}, cv=5, genotype=c(0,1,2))

# plotting needs to occur before transforming the model
# names for the summary data
plot(fit,data=mdr_data)

# transform models for snp names instead of just numbers
# this may only matter when not using synthesized data
topm<-nameModels(fit$'top models')
fit$'top models'<-topm

finalm<-nameModels(fit$'final model')
fit$'final model'<-finalm

out<-capture.output(summary(fit))
cat(out,file="#{opts[:output_path]}/summary_#{base}.txt", sep="\n", append=TRUE)
  R
  return r_script
end

# Start main
$config = ARGV[0] if ARGV.length > 0
cfg = Utils.check_config($config)

unless File.directory?(cfg['chr.output']) and File.exists?(cfg['chr.output'])
  raise IOError, "#{cfg['chr.output']} does not exist or is not a directory."
end


output_dir = "#{cfg['mdr.analysis.dir']}/#{Utils.date}"
oar_dir = "#{cfg['oar.dir']}/#{Utils.date}"

[output_dir, oar_dir].each do |d|
  if File.exists?(d) and File.directory?(d)
    puts "Removing old directory #{d}"
    FileUtils.remove_entry_secure("#{d}")
  end
   FileUtils.mkdir_p(d)
end

write_scripts(:input_path => cfg['chr.output'],
              :output_path => output_dir,
              :k => cfg['mdr.K'],
              :max => cfg['mdr.max'],
              :oar => oar_dir)

run_scripts(cfg)

puts "Finished..."




