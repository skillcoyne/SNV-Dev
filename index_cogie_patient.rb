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


if ARGV.length < 1
  puts "Usage: #{$0} <cogie.config>"
  exit 1
end

cfg = YAML.load_file(ARGV[0])

unless cfg.has_key?'patient.vcf' and cfg.has_key?'qual.range' and cfg.has_key?'output.dir'
  warn "Config file missing one or more required properties:  patient.vcf, qual.range, output.dir. Exiting."
  exit -1
end

# Get patient variations in each location and create separate chromosome vcf files
patients_file = cfg['patient.vcf']
outdir = "#{cfg['output.dir']}/#{File.basename(patients_file, '.vcf')}"

FileUtils.mkpath(outdir) unless File.exists?outdir

# Quality range
qual = cfg['qual.range'].split("-")
qual_range = Range.new(qual[0].to_f, qual[1].to_f)

File.open("#{outdir}/run-info.txt", 'a') { |f|
  f.write(DateTime.now.to_s + "\n")
  f.write("Patient file: #{patients_file}\n")
  f.write("Qual range: #{qual_range}\n")
}

count = 0
loc_file = "#{outdir}/chr_locations.#{qual[0]}-#{qual[1]}.txt"
puts "Writing to #{loc_file}"

locations = {}
patient_ids = []
File.open(patients_file, 'r').each_with_index do |line, i|
  next if line.start_with? "##"
  if line.start_with? "#CHROM"
    cols = line.chomp.split("\t")
    patient_ids = cols[9..cols.size-1]
    next
  end
  #puts i
  v = COGIE::VCF.new(line, patient_ids)
  next unless v.info['TYPE'].eql? 'SNP' and qual_range.include?(v.qual)
  count += 1
  (locations[v.chr] ||= []) << v.pos
  #break if count > 500
end

if locations.length > 0
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
else
  warn "No locations for range: #{qual_range}"
end
