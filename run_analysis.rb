require 'rubygems'
require 'fileutils'
require 'yaml'

$script = "mdrAnalysis.R"


def write_scripts(input_path, output_path)
  Dir.foreach(input_path) do |entry|
    full_file_path = "#{input_path}/#{entry}"
    next unless File.extname(full_file_path).eql?".mdr"

    r_script = script_string(full_file_path, output_path)

    filename = File.basename(full_file_path, ".mdr")

    File.open("#{output_path}/#{filename}_#{$script}", 'w') {|f|
      f.write(r_script)
    }
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

def script_string(input, output_dir)
  base = File.basename(input, ".mdr")
  # this can be an option at some point but currently larger K takes many times longer to run
  k=2
  # more data takes longer to run
  max=50
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

mdr_data<-read.table("#{input}", header=TRUE)

#note if you don't slice the array you need to be aware of
# an off by 1 error in the nameModels function
cols<-colnames(mdr_data[2:#{max}])
fit<-mdr.cv(mdr_data[1:#{max}], K=#{k}, cv=5, genotype=c(0,1,2))

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
cat(out,file="#{output_dir}/summary.txt", sep="\n", append=TRUE)
  R
  return r_script
end

# Start main
if ARGV.length < 2
  raise ArgumentError, "Missing arguments.  Usage: script.rb [input_file_path] [output_file_path]"
end

input_dir = ARGV[0]
output_dir = ARGV[1]

unless File.directory?(input_dir) and File.exists?(input_dir)
  raise IOError, "#{input_dir} does not exist or is not a directory."
end

if File.exists?(output_dir)
  begin # doesn't matter if it fails to remove, it probably wasn't there in the first place
    eval FileUtils.remove_entry_secure("#{output_dir}")
    rescue Errno, "#{output_dir} doesn't exist, not removing."
  end

  FileUtils.mkdir(output_dir)
end

Dir.mkdir(output_dir) unless File.exists?(output_dir)


write_scripts(input_dir, output_dir)
run_scripts(output_dir)

puts "Finished..."




