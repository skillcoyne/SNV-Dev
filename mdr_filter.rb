require 'fileutils'
require 'yaml'
require 'vcf'

require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/cogie_patient'
require_relative 'lib/control_sample'
require_relative 'lib/func'
require_relative 'lib/simple_matrix'


## TODO: Need to go back to this...the ranked locations cannot be sorted!

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
  #locations.each_pair { |k, v| locations[k] = v.sort! }
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

# Get the locations in rank order
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
  patient_locations[chr] = line[1..-1].map! { |e| Integer(e) }
end


# Filter out patient locations that don't fit the ranked list
ranged_locations = {}
ranked_locations.each_pair do |chr, list|
  ranged_locations[chr] = list.map { |e| Range.new(e[0], e[1]) }
end

filtered_patients = Hash[ranged_locations.keys.map { |l| [l, []] }]

ranged_locations.each_pair do |chr, ranges|
  #next unless chr == '12'
  next unless patient_locations.has_key? chr
  patient_locations[chr].each do |ploc|
    ranges.each do |range|
      if range.include? ploc
        filtered_patients[chr] << ploc
        break
      end
    end
  end
end
filtered_patients.delete_if { |chr, list| list.length <= 0 }
temp_filt_pts = {}
filtered_patients.each_pair { |k, list|
  list.sort!
  list.push(list[-1]+100) if list.length%2 > 0
  temp_filt_pts[k] = list.each_slice(2).to_a
}
filtered_patients = temp_filt_pts

#puts YAML::dump filtered_patients['12']
#
#exit

## Get control variations for the list of patient variations?

## -- CONTROLS -- ##
# Get variations for controls in each location that patients also have variations
# Am not including all possible locations in the control file as that will greatly increase
# the MDR files and decrease possible hits
puts "Getting control variations."

ctrl_temp = "#{cfg['output.dir']}/vcf"
FileUtils.mkpath(ctrl_temp) unless File.exists?(ctrl_temp)

mdr_temp = "#{cfg['output.dir']}/mdr"
FileUtils.rm_rf(mdr_temp) if File.exists?mdr_temp
FileUtils.mkpath(mdr_temp)

## pull out subsets of the VCF files first ## TODO THIS IS NOT FINISHED / WORKING IN ANY SENSE, was just moving code around

filtered_patients.each_pair do |chr, locations|
  next unless chr.eql? '12'
  file = "#{cfg['control.var.loc']}/#{control_vcf[chr]}"
  mdr = SimpleMatrix.new()

  files = []
  locations.each_with_index do |lp, i|
    ctrl = COGIE::ControlSample.new(file, {:tabix => "#{chr}:#{lp.join("-")}}", :out => ctrl_temp})
    ctrl.parse_variations
    puts "Variations parsed...for #{lp}"

    ctrl.pos.sort.map do |position, samples|
      mdr.rownames = samples.map{|s,v| s }
      mdr.add_column(position,  samples.map {|s, v| v['GT'] })
      puts "Current size: " +  mdr.size.join(", ")

    end
  end
  filename = "#{mdr_temp}/#{chr}.txt"
  mdr.write(filename)

  #puts "Contatenating #{files.length} files to #{cfg['output.dir']}/#{chr}.txt"
  #system("cat #{files.join(" ")} > #{cfg['output.dir']}/#{chr}.txt")
  #FileUtils.remove(files)
end





exit

#ranked_locations.each_pair do |chr, location_pairs|
#  next unless chr.eql? '12'
#  controls[chr] = []
#  file = "#{cfg['control.var.loc']}/#{control_vcf[chr]}"
#  location_pairs.map! { |lp| controls[chr] << COGIE::ControlSample.new(file, {:tabix => "#{chr}:#{lp.join("-")}}", :out => ctrl_temp}) }
#end
#
#
#filtered_patients.each_pair do |chr, locations|
#  puts "#{chr} #{locations.length}"
#end
#
#exit
#
#filtered_patients.each_pair do |chr, locations|
#  next unless chr.eql? '12'
#  locations.each do |loc|
#    ranked_locations[chr]
#  end
#  location_pairs.each do |lp|
#    ctrl = COGIE::ControlSample.new(file, {:tabix => "#{chr}:#{lp.join("-")}}", :out => ctrl_temp})
#    current_range = Range.new(lp[0], lp[1])
#
#    filtered_patients[chr].each do |loc|
#      puts loc
#      if current_range.include? loc
#        puts "*** #{loc}"
#      end
#    end
#  end
#end

#puts YAML::dump ranked_locations['12']


#all_locs = []
#puts "Getting locations from #{ctrl.ct_file}"
#File.open(ctrl.ct_file, 'r').each_with_index do |line, index|
#  next if line.start_with? "#"
#  printf "." if index%50 == 0
#  v = Vcf.new(line)
#  all_locs << v.pos
#  puts YAML::dump v
##      COGIE::Func.mdr_genotype(v.samples['1']['GT'])
#  break if index > 20
#end
#puts ""
#end
#end
#

