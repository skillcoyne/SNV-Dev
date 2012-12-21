require 'fileutils'
require 'yaml'
require 'vcf'

require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/cogie_patient'
require_relative 'lib/control_sample'
require_relative 'lib/func'


def load_filter_locations(filterfile, gi)
  locations = {}

  File.open(filterfile, 'r').each_with_index do |line, index|
    line.chomp!
    cols = line.split("\t")

    # location
    if cols[0].match(/^\d+|X|Y|MT/)
      chr_start = Integer(cols[1])
      chr_end = Integer(cols[2])
      locations[cols[0]] = [] unless locations.has_key?(cols[0])
      locations[cols[0]] << [chr_start, chr_end]
    else # gene
      gene = cols[0]
      raise Exception, "ENSEMBL gene identifiers are required currently, please translate gene names in your filter file first (#{gene})" unless gene.match(/ENSG\d+/)
      info = gi.get_info(gene)
      next if info.nil?
      locations[info[:chr]] = [] unless locations.has_key?(info[:chr])
      locations[info[:chr]] << [info[:start], info[:end]] unless info.nil?
    end
  end
  locations.each_pair { |k, v| locations[k] = v.sort! }
  return locations
end


## TODO: Need to create the control MDR matrix only once per filter
if ARGV.length < 1
  puts "Usage: #{$0} <configuration file>"
  exit
end


## Inputs
# Configuration file, see resources/cogie.config.example
config_defaults = YAML.load_file("resources/cogie.config.example")
cfg = Utils.check_config(ARGV[0], config_defaults)

ranked_locations = load_filter_locations(cfg['ranked.list'], EnsemblInfo.new(cfg['gene.loc']))


# List control VCF files
## This assumes that the control files are organized per chromosome, but since I'm using 1000genomes
## data that's a safe assumption
control_files = Dir.entries(cfg['control.var.loc'])
control_vcf = {}
control_files.each do |f|
  if f.match(/\w+\.chr(\w+)\..+\.gz$/)
    chr = $1
    control_vcf[chr] = f
  end
end

## All patient variation locations by chromosome
loc_file = "#{cfg['patient.var.loc']}/chr_locations.txt"
patient_locations = {}
File.open(loc_file, 'r').each_line do |line|
  line.chomp!
  next if line.start_with? "#"
  line = line.split("\t")
  chr = line.slice!(0)
  patient_locations[chr] = line[1..-1].map!{|e| Integer(e) }
end


# Filter out patient locations that don't fit the ranked list
ranged_locations = {}
ranked_locations.each_pair do |chr, list|
  ranged_locations[chr] = list.map { |e| Range.new(e[0], e[1]) }
end

filtered_patients = Hash[ranged_locations.keys.map{|l| [l, []]}]
ranged_locations.each_pair do |chr, ranges|
  next unless chr == '12'
  patient_locations[chr].each do |ploc|
    ranges.each do |range|
      if range.include?ploc
        filtered_patients[chr] << ploc
        break
      end
    end
  end
end
filtered_patients.each_pair{ |k,list| list.sort! }

## Get control variations for the list of patient variations?


## -- CONTROLS -- ##
# Get variations for controls in each location
puts "Getting control variations."


ctrl_temp = "#{cfg['output.dir']}/vcf-tmp"
FileUtils.mkpath(ctrl_temp) unless File.exists?(ctrl_temp)

## pull out subsets of the VCF files first ## TODO THIS IS NOT FINISHED / WORKING IN ANY SENSE, was just moving code around
ranked_locations.each_pair do |chr, location_pairs|
  next unless chr.eql? '12'
  file = "#{cfg['control.var.loc']}/#{control_vcf[chr]}"

  location_pairs.each do |lp|
    ctrl = COGIE::ControlSample.new(file, {:tabix => "#{chr}:#{lp.join("-")}}", :out => ctrl_temp})

    all_locs = []
    File.open(ctrl.ct_file, 'r').each_line do |line|
      next if line.start_with? "#"
      v = Vcf.new(line)
      all_locs << v.pos
#      COGIE::Func.mdr_genotype(v.samples['1']['GT'])
    end

  end
end


filtered_patients.each do |chr, list|
  next unless chr == '12'

end
