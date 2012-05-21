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

    r_script = R_script_string(opts)
    filename = File.basename(opts[:input_file], ".mdr")

    File.open("#{opts[:output_path]}/#{filename}_#{$script}", 'w') { |f| f.write(r_script) }
    FileUtils.chmod(0776, "#{opts[:output_path]}/#{filename}_#{$script}")

    opts[:r_script] = "#{opts[:output_path]}/#{filename}_#{$script}"
  end
end

# Expected options:
# :input_file, :output_path, :k, :max
def R_script_string(opts = {})
  base = File.basename(opts[:input_file]).sub(".mdr", '')
  r_script =<<-R
#!/usr/bin/env Rscript
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
pdf("#{opts[:output_path]}/#{base}_plot.pdf")
plot(fit,data=mdr_data)

# transform models for snp names instead of just numbers
# this may only matter when not using synthesized data
topm<-nameModels(fit$'top models')
fit$'top models'<-topm

finalm<-nameModels(fit$'final model')
fit$'final model'<-finalm

summary(fit)

#out<-capture.output(summary(fit))
#cat(out,file="#{opts[:output_path]}/summary_#{base}.txt", sep="\n", append=TRUE)
  R
  return r_script
end

def run_scripts(opts = {})
  script_path = opts[:output_path]
  puts script_path
  Dir.foreach(script_path) do |entry|
    puts entry
    next unless File.extname(entry).eql? ".r"
    chr = File.basename(opts[:input_file]).sub("_mdrAnalysis.R", '')
    cmd = "oarsub -l core=#{opts[:cores]},walltime=#{opts[:walltime]}"
    cmd = "#{cmd} -n MDR_#{chr} --stdout=#{script_path}/summary_#{chr}.out --stderr=#{script_path}_#{chr}.err  #{script_path}/#{entry}"
    puts "Starting #{entry}"
    system("#{cmd}")
  end
end

### -------- Start main -------- ###
$config = ARGV[0] if ARGV.length > 0
cfg = Utils.check_config($config)

unless File.directory?(cfg['chr.output']) and File.exists?(cfg['chr.output'])
  raise IOError, "#{cfg['chr.output']} does not exist or is not a directory."
end


output_dir = "#{cfg['mdr.analysis.dir']}/#{Utils.date}"

if File.exists?(output_dir) and File.directory?(output_dir)
  puts "Removing old directory #{output_dir}"
  FileUtils.remove_entry_secure("#{output_dir}")
end
FileUtils.mkdir_p(output_dir)

write_scripts(:input_path => cfg['chr.output'],
              :output_path => output_dir,
              :k => cfg['mdr.K'],
              :max => cfg['mdr.max'],
              :oar => oar_dir)

run_scripts(:output_path => output_dir,
            :cores => cfg['oar.core'],
            :walltime => cfg['oar.walltime'],
            :email => cfg['oar.notify'])

puts "Finished..."