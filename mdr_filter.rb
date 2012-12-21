require 'fileutils'
require 'yaml'

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

def pos_to_sample(ctrl)
  gt = {}
  ctrl.pos.each_pair do |pos, vcf|

  end


end


## TODO: Need to create the control MDR matrix only once per filter
if ARGV.length < 1
  puts "Usage: #{$0} <configuration file>"
  exit
end


## Inputs
# Configuration file, see resources/cogie.config.example
cfgfile = ARGV[0]

config_defaults = YAML.load_file("resources/cogie.config.example")
cfg = Utils.check_config(cfgfile, config_defaults)
filter_file = cfg['ranked.list']
info = EnsemblInfo.new(cfg['gene.loc'])

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

ranked_locations = load_filter_locations(filter_file, info)
#ranked_locations.each do |loc|
#  puts loc.join(",")
#end

## -- PATIENTS -- ##


## -- CONTROLS -- ##
# Get variations for controls in each location
puts "Getting control variations."

Dir.foreach(cfg['control.var.loc']) do |entry|
  file = "#{cfg['control.var.loc']}/#{entry}"
  File.open(file, 'r')
end


ctrl_temp = "#{cfg['output.dir']}/vcf-tmp"
FileUtils.mkpath(ctrl_temp) unless File.exists?(ctrl_temp)

ranked_locations.each_pair do |chr, list|
  next unless chr.eql? '12'
  file = "#{cfg['control.var.loc']}/#{control_vcf[chr]}"

  list.each do |loc|
    mdr_file = "temp.mdr"
    ctrl = COGIE::ControlSample.new(file, {:tabix => "#{chr}:#{loc[0]}-#{loc[1]}", :out => ctrl_temp})

    ##positions = ctrl.pos.keys
    #puts "Sample\t" + positions.join("\t")
    #ctr.pos.each_pair do |pos, vcf|
    #  print "#{pos}\t"
    #  ctrl.samples.each do |s|
    #
    #  end
    end
  end
end
