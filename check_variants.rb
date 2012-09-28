require 'fileutils'
require 'json'
require_relative 'lib/query'


unless ARGV.length > 0
  warn("DocSet snp descriptions file required.")
  exit
end


file = ARGV[0]
id = nil; maf = nil; validated = false; func_class = nil
entries = Array.new

index = 0
File.open(file, 'r') do |infile|
  while (line = infile.gets)
    if (line.match(/rs\d+/) or infile.eof) and index > 1

      puts "#{id}\t#{maf}\t#{func_class}"

      entries.push("#{id}\t#{maf}\t#{func_class}") if validated and maf # push last set

      id = line.match(/rs\d+/)
      maf = nil; validated = false; func_class = nil
    end

    maf = line.sub("GLOBAL_MAF=", "") if line.start_with?("GLOBAL_MAF")
    validated = true if line.start_with?("VALIDATED") and !line.eql?("VALIDATED=no-info")
    func_class = line.sub("FXN_CLASS=", "") if line.start_with?("FXN_CLASS")
    index = index + 1
  end
end


