require 'fileutils'
require 'yaml'

require_relative 'lib/utils'
require_relative 'lib/cogie'

## This script essentially indexes (cheaply, no true index is created) the patient files.
## All patients the directory indicated by the configuration file will be read and two actions performed.
# 1) All chromosome locations with variations are output (in order) to a file called chr_locations.txt.  This file
#    is used by the mdr_filter script to determine if a variation is present in the patient files.
# 2) Each patient file is broken up into multiple .func files by chromosome.  This makes reading them in the filter
#    script simpler and faster.

if ARGV.length < 1
  puts "Usage: #{$0} <patient file>"
  exit 2
end


file = ARGV[0]
dir = File.dirname(file)

locations = {}

puts "Reading patient file #{file}..."
patient = File.basename(file).sub!(/\..*$/, "")
# Make a directory for each patient. The chromsome .func files will be output here.
patient_dir = "#{dir}/#{patient}"

FileUtils.rm_rf(patient_dir) if (File.exists? patient_dir and File.directory? patient_dir)
FileUtils.mkpath(patient_dir)

# Get patient variations in each location
loc_file = "#{patient_dir}/chr_locations.txt"

begin
  # Read the .func file
  File.open(file, 'r').each_with_index do |line, index|
    next unless index > 2
    next if line.start_with? "#" # the header lines are repeated throughout the file
                                 #printf "." if index%500 == 0; #printf "\n" if index%(500*200) == 0
    func = COGIE::Func.parse_line(line)
    # Write to corresponding chromosome file
    chr_file = "#{patient_dir}/Chr#{func.chr}.func"
    (File.exists? chr_file) ? (wa = 'a') : (wa = 'w')
    File.open(chr_file, wa) { |fout| fout.write("#{line}\n") }
    locations[func.chr] = [] unless locations.has_key? func.chr
    locations[func.chr] << func.from
  end
rescue COGIE::FileFormatError => e # Note that the file format expected is specific to the COGIE project.
  warn "Error reading #{file}: #{e.message}"
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
