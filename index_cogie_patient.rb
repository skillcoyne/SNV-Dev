require 'fileutils'
require 'yaml'

#require 'vcf'

require_relative 'lib/utils'
require_relative 'lib/cogie'

## This script essentially indexes (cheaply, no true index is created) the patient files.
## All patients the directory indicated by the configuration file will be read and two actions performed.
# 1) All chromosome locations with variations are output (in order) to a file called chr_locations.txt.  This file
#    is used by the mdr_filter script to determine if a variation is present in the patient files.
# 2) Each patient file is broken up into multiple .func files by chromosome.  This makes reading them in the filter
#    script simpler and faster.


if ARGV.length < 2
  puts "Usage: #{$0} <patient VCF file> <qual range e.g. 72:220>"
  exit 1
end

# Get patient variations in each location
patient_file = ARGV[0]
#patient_file = "/Volumes/Spark/Data/COGIE/patients/ige03052013.ls.vcf"

#qual = [255, 47300]
qual = ARGV[1].split(":")
qual_range = Range.new(qual[0], qual[1])

loc_file = "#{File.dirname(patient_file)}/chr_locations.#{qual[0]}-#{qual[1]}.txt"

locations = {}
patient_ids = []
File.open(patient_file, 'r').each_with_index do |line, i|
  next if line.start_with? "##"
  if line.start_with?"#CHROM"
    cols = line.chomp.split("\t")
    patient_ids = cols[9..cols.size-1]
    next
  end
    puts i
    v = COGIE::VCF.new(line, patient_ids)

    next unless v.info['TYPE'].eql?'SNP' and qual_range.include?(v.qual)

    (locations[v.chr] ||= []) << v.pos
end


locations.each_pair { |k, v| v.uniq!; v.sort! }

# Chromosome locations file
locations = Hash[locations.sort]
File.open(loc_file, 'w') do |fout|
  fout.write "# Each line is formatted as: <chr> <list of locations from patient files>\n"
  locations.each_pair do |chr, locs|
    fout.write "#{chr}\t" + locs.join("\t") + "\n"
  end
end

puts "\n#{loc_file} written."
