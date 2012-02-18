require 'rubygems'
require 'yaml'
require_relative 'lib/mdr_script'

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
    break
  end
end

def script_string(input, output_dir)
  base = File.basename(input, ".mdr")
  r_script =<<-R
library(MDR)

file="#{input}"

mdr_data<-read.table(file, header=TRUE)

fit<-mdr.cv(mdr_data[1:15], K=2, cv=5, genotype=c(0,1,2))

out<-capture.output(summary(fit))
cat(out,file="#{output_dir}/#{base}.summary.txt", sep="\\n", append=TRUE)

plot(fit,data=mdr_data)
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

Dir.mkdir(output_dir) unless File.exists?(output_dir)


write_scripts(input_dir, output_dir)
run_scripts(output_dir)

puts "Finished..."




