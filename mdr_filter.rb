require 'fileutils'
require 'yaml'
require 'vcf'


require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/cogie_patient'
require_relative 'lib/control_sample'
require_relative 'lib/func'
require_relative 'lib/simple_matrix'


def load_filter_locations(filterfile, gi)
  locations = []

  File.open(filterfile, 'r').each_with_index do |line, index|
    line.chomp!
    cols = line.split("\t")

    # location
    if cols[0].match(/^\d+|X|Y|MT/)
      chr = cols[0]
      from = Integer(cols[1])
      to = Integer(cols[2])
      r = Range.new(from, to)
    else # gene
      gene = cols[0]
      raise Exception, "ENSEMBL gene identifiers are required currently, please translate gene names in your filter file first (#{gene})" unless gene.match(/ENSG\d+/)
      info = gi.get_info(gene)
      next if info.nil?
      chr = info[:chr]
      r = Range.new(info[:start], info[:end])
    end
    locations << [r, chr]
  end
  return locations
end


# Reads through the .func file provided and returns the variation at the given location
def find_patient_variation(file, location)
  #puts "Reading #{file} for #{location}..."
  File.open(file, 'r').each_with_index do |line, i|
    line.chomp!; next if line.start_with? "#"
    begin
      cf = COGIE::Func.new(line)
      ## NOTE: in this case we are dealing only with SNPs
      if cf.from.eql? location
        return cf.genotype
      end
    rescue COGIE::FileFormatError => e
      warn "Error reading #{file} at line #{i}: #{e.message}"
    end
  end
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
# DO NOT SORT!
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

# Patient files
## All patient variation locations by chromosome
patient_dirs = []
patient_files = Dir.entries(cfg['patient.var.loc'])
patient_files.each do |f|
  if f.match(/\.func$/)
    pdir = "#{cfg['patient.var.loc']}/" + File.basename(f).sub!(/\..*$/, "")
    raise StandardError, "Patient directories missing. Please rerun patient file indexing script." unless (File.exists? pdir and File.directory? pdir)
    patient_dirs << pdir
  end
end

loc_file = "#{cfg['patient.var.loc']}/chr_locations.txt"
patient_locations = {}
File.open(loc_file, 'r').each_line do |line|
  line.chomp!
  next if line.start_with? "#"
  line = line.split("\t")
  chr = line.slice!(0)
  patient_locations[chr] = line[1..-1].map! { |e| Integer(e) }
end


ranked_patient_locations = Hash[ranked_locations.each_with_index.map { |e, i| [i, nil] }]
ranked_locations.each_with_index do |rl, i|
  range = rl[0]
  chr = rl[1]
  next unless patient_locations.has_key? chr
  pt_list = patient_locations[chr]
  pt_list = pt_list.select { |e| range.include? e }
  ranked_patient_locations[i] = COGIE::Locations.new(pt_list, chr) unless pt_list.empty?
end
ranked_patient_locations.delete_if { |k, v| v.nil? }

# Join the ranks until you hit the mdr max value
# Right now not worrying too much about getting it just right
max = cfg['mdr.max']
cat_ranks = {}
n = 0
count = 0
ranked_patient_locations.each_pair do |rank, cl|
  cat_ranks[n] = [] unless cat_ranks.has_key? n
  count += cl.locations.length
  if count > max
    n +=1; count = 0
  else
    cat_ranks[n] << cl
  end
end
ranked_patient_locations = cat_ranks

## Get control variations for the list of patient variations?

## -- CONTROLS -- ##
# Get variations for controls in each location that patients also have variations
# Am not including all possible locations in the control file as that will greatly increase
# the MDR files and decrease possible hits
puts "Getting control variations."

ctrl_temp_dir = "#{cfg['output.dir']}/vcf"
FileUtils.rm_rf(ctrl_temp_dir) if File.exists? ctrl_temp_dir
FileUtils.mkpath(ctrl_temp_dir)

mdr_temp_dir = "#{cfg['output.dir']}/mdr"
FileUtils.rm_rf(mdr_temp_dir) if File.exists? mdr_temp_dir
FileUtils.mkpath(mdr_temp_dir)

## pull out subsets of the VCF files first ##
ordered_locations = Hash[ranked_patient_locations.map { |k, v| [k, [v.map { |e| e.locations }].flatten!] }]
ranked_patient_locations.sort.map do |rank, locations|
  next if File.exists? "#{cfg['output.dir']}/Rank#{rank}-ctrl.txt" ##TODO DO NOT LEAVE THIS HERE
  mdr = SimpleMatrix.new()
  locations.each do |cvp|
    file = "#{cfg['control.var.loc']}/#{control_vcf[cvp.chr]}"
    cvp.locations.each do |loc|
      ctrl = COGIE::ControlSample.new(file, {:tabix => "#{cvp.chr}:#{loc}-#{loc}}", :out => ctrl_temp_dir})
      vars = ctrl.parse_variations
      mdr.rownames = ctrl.samples.map { |s, v| "Sample-#{s}" } if mdr.rownames.empty?
      vars.each do |var|
        mdr.add_column(var.pos, var.samples.map { |s, v| COGIE::Func.mdr_genotype(v['GT']) })
      end
      ## Sometimes the control files do not list that variation.
      ## In this case presume GT = 0
      if vars.empty?
        col = Array.new(mdr.size[0])
        mdr.add_column(loc, col.map { |e| e = 0 })
      end
    end
  end
  class_col = Array.new(mdr.size[0])
  mdr.add_column('Class', class_col.map { |e| e = 0 })
  mdr.write("#{cfg['output.dir']}/Rank#{rank}-ctrl.txt")
end

## -- PATIENTS -- ##
# Patient directories where each chromosome file is kept
puts "Getting patient variations."
ranked_patient_locations.sort.map do |rank, locations|

  row = []
  locations.each do |cvp|
    cvp.locations.each do |loc|
      patient_dirs.each do |dir|
        row << File.basename(dir) unless row.index(File.basename(dir)) # patient name
        fcfile = "#{dir}/Chr#{cvp.chr}.func"
        gt = find_patient_variation(fcfile, loc)
                                                                       # Genotype will be nil or an empty string if the variation was not a SNP
                                                                       # Currently we're only dealing with SNPs
        (gt.nil? or gt.eql? "") ? (row << "0") : (row << COGIE::Func.mdr_genotype(gt))
      end
    end
  end
  # Add the class variable to the row
  row << "1"
  mdrfile = "#{cfg['output.dir']}/Rank#{rank}-ctrl.txt"
  FileUtils.copy(mdrfile, "#{cfg['output.dir']}/mdr/Rank#{rank}.txt")
  mdrfile = "#{cfg['output.dir']}/mdr/Rank#{rank}.txt"
  puts "Writing #{mdrfile}"
  File.open(mdrfile, 'a') { |f| f.write(row.join("\t") + "\n") }
end


