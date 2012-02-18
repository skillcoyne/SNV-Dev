require 'rubygems'
require 'fileutils'
require 'yaml'

$script = "mdrAnalysis.R"

# Expected options:
# :input_path, :output_path, :k, :max
def write_scripts(opts = {})
  Dir.foreach(opts[:input_path]) do |entry|
    opts[:input_file] = "#{opts[:input_path]}/#{entry}"
    next unless File.extname(opts[:input_file]).eql?".mdr"

    r_script = script_string(opts)
    filename = File.basename(opts[:input_file], ".mdr")

    File.open("#{opts[:output_path]}/#{filename}_#{$script}", 'w') {|f| f.write(r_script)}
  end
end

def run_scripts(script_path)
  Dir.foreach(script_path) do |entry|
    next unless File.extname(entry).eql?".R"
    puts "Running #{script_path}/#{entry}"
    cmd = "r --vanilla #{script_path}/#{entry}"
    system(cmd)
  end
end

# Expected options:
# :input_file, :output_path, :k, :max
def script_string(opts = {})
  base = File.basename(opts[:input_file], ".mdr")
  # this can be an option at some point but currently larger K takes many times longer to run
  r_script =<<-R
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
cat(out,file="#{opts[:output_path]}/summary.txt", sep="\n", append=TRUE)
  R
  return r_script
end

# Start main
if ARGV.length < 2
  raise ArgumentError, "Missing arguments.  Usage: script.rb [input_file_path] [output_file_path] [k] [max]"
end

input_dir = ARGV[0]
output_dir = ARGV[1]
kval = ARGV[2] or 2
maxSNP = ARGV[3] or 50

unless File.directory?(input_dir) and File.exists?(input_dir)
  raise IOError, "#{input_dir} does not exist or is not a directory."
end

if File.exists?(output_dir)
  puts "Removing old #{output_dir}"
#  begin # doesn't matter if it fails to remove, it probably wasn't there in the first place
#    FileUtils.remove_entry_secure("#{output_dir}")
#  end

#  FileUtils.mkdir(output_dir)
end

Dir.mkdir(output_dir) unless File.exists?(output_dir)

write_scripts(:input_path => input_dir, :output_path => output_dir, :k => kval, :max => maxSNP)
#write_scripts(input_dir, output_dir, kval, maxSNP)
#run_scripts(output_dir)

puts "Finished..."




