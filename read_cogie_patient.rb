require 'fileutils'
require 'yaml'

require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/cogie_patient'
require_relative 'lib/control_sample'
require_relative 'lib/func'
require_relative 'lib/simple_matrix'


if ARGV.length < 1
  puts "Usage: #{$0} <configuration file>"
  exit
end

config_defaults = YAML.load_file("resources/cogie.config.example")
cfg = Utils.check_config(ARGV[0], config_defaults)


## Two pass read
# 1. Read all patient files and get all locations by chromosome?
# 2. Break up the patient file by chromosome for simplicity.

## 1st PASS
# Get patient variations in each location
loc_file = "#{cfg['patient.var.loc']}/chr_locations.txt"
puts "Output text file of all patient variation locations by chromosome. Break up each patient file by chromosome."
locations = {}
Dir.foreach(cfg['patient.var.loc']) do |entry|
  next unless entry.match(/\.func$/)
  file = "#{cfg['patient.var.loc']}/#{entry}"

  puts "Reading patient file #{file}..."

  patient_dir = "#{cfg['patient.var.loc']}/" + File.basename(file).sub!(/\..*$/, "")
  FileUtils.rm_rf(patient_dir) if (File.exists?patient_dir and File.directory?patient_dir)
  FileUtils.mkpath(patient_dir)

  begin
    File.open(file, 'r').each_with_index do |line, index|
      next unless index > 2
      next if line.start_with? "#" # the header lines are repeated throughout the file
      printf "." if index%500 == 0; printf "\n" if index%(500*200) == 0

      func = COGIE::Func.parse_line(line)

      # Write to corresponding chromosome file
      chr_file = "#{patient_dir}/Chr#{func.chr}.func"
      (File.exists? chr_file) ? (wa = 'a') : (wa = 'w')
      File.open(chr_file, wa) { |fout| fout.write("#{line}\n") }

      locations[func.chr] = [] unless locations.has_key? func.chr
      locations[func.chr] << func.from
    end

  rescue COGIE::FileFormatError => e
    warn "Error reading #{file}: #{e.message}"
    puts e.backtrace
  end
  locations.each_pair { |k, v| v.uniq!; v.sort! }
end
# This file will be used later
locations = Hash[locations.sort]
File.open(loc_file, 'w') do |fout|
  fout.write "# Each line is formatted as: <chr> <list of locations from patient files>\n"
  locations.each_pair do |chr, locs|
    fout.write "#{chr}\t" + locs.join("\t") + "\n"
  end
end


exit


## 2nd PASS, create MDR files per chromosome
mdrdir = "#{cfg['patient.var.loc']}/mdr"
#if File.exists? mdrdir
#  puts "MDR files have already been generated for these patients. If new data has been added please remove the locations file (#{loc_file}) and the mdr directory (#{mdrdir}) and rerun."
#  exit
#end

FileUtils.mkpath(mdrdir)
File.open(loc_file, 'r').each_line do |line|
  line.chomp!
  next if line.start_with? "#"
  line = line.split("\t")
  chr = line[0]

  locs = line[1..-1]
  locs.map! { |l| Integer(l) }

  puts "Writing MDR file for chromosome #{chr}."
  #mdr = SimpleMatrix.new()

  mdr_file = "#{mdrdir}/Chr#{chr}.txt"
  mdrout = File.open(mdr_file, 'w')
  mdrout.write "\t" + locs.join("\t") + "\tClass\n"

  Dir.foreach(cfg['patient.var.loc']) do |entry|
    next unless entry.match(/\.func/)
    ptfile = "#{cfg['patient.var.loc']}/#{entry}"
    mdrout.write File.basename(ptfile).sub!(/\..*$/, "") + "\t"

    begin
      puts "\tReading patient file #{ptfile}..."
      variations = []
      File.open(ptfile, 'r').each_with_index do |line, index|
        next unless index > 2
        next if line.start_with? "#" # the header lines are repeated throughout the file
        printf "." if index%500 == 0; printf "\n" if index%(500*200) == 0

        func = COGIE::Func.parse_line(line)
        next unless func.chr.eql? chr
        variations << func
      end

      variations = Hash[variations.map { |v| [v.from, v] }]
      puts "\nOutputting MDR file #{locs.length} for locations..."
      locs.each do |l|
        out = "NA"
        if variations.has_key? l
          if variations[l].type.eql? "SNP"
            out = COGIE::Func.mdr_genotype(variations[l]).to_s
          end
        else # no entry at that location we can assume it's normal I guess
          out = "0"
        end
        mdrout.write "#{out}\t"
      end

    rescue COGIE::FileFormatError => e
      warn "Error reading #{file}: #{e.message}"
      puts e.backtrace
    end
    mdrout.write "1\n" # Class variable, 1=Patient
    mdrout.close
  end
end

