require 'fileutils'
require 'yaml'
require 'vcf'

require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/control_sample'
require_relative 'lib/cogie'
require_relative 'lib/simple_matrix'
require_relative 'lib/mdr_script'

# Read filter file.  Two possible formats for each line (the file can be a mix of these):
# 1)  chr   from-location   to-location
# 2)  ensembl-gene-id     <anything else is ignored>
# An UNSORTED list of locations (ranges) and chromosomes is returned.
# This list must stay unsorted as the filter file is presumed to be provided in RANKED order and the list
# preserves the ranking.
def load_filter_locations(filterfile, gi)
  locations = []
  File.open(filterfile, 'r').each_with_index do |line, index|
    line.chomp!
    cols = line.split("\t")
    if cols[0].match(/^\d+|X|Y|MT/) # location
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


### ---- START MAIN ---- ###
if ARGV.length < 1
  puts "Usage: #{$0} <configuration file>\nSee the cogie.config.example file."
  exit 2
end


## Configuration file is expected as input.  Read.
# see resources/cogie.config.example
config_defaults = YAML.load_file("resources/cogie.config.example")
cfg = Utils.check_config(ARGV[0], config_defaults, ['mdr.jar', 'tabix.path'])

# Get the locations in rank order
ranked_locations = load_filter_locations(cfg['ranked.list'], EnsemblInfo.new(cfg['gene.loc']))
puts "Reading in filtered locations #{cfg['ranked.list']}"

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
    unless (File.exists? pdir and File.directory? pdir)
      puts "ERROR: Patient directories missing. Please rerun patient file indexing script."
      exit 2
    end
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
# Right now not worrying too much about getting it just right, a few above the max mdr value won't make a huge
# different computationally.  It's the k value that will cause the issues.
max = cfg['mdr.max']
cat_ranks = {}
n = 0; count = 0
ranked_patient_locations.each_pair do |rank, cl|
  cat_ranks[n] = {} unless cat_ranks.has_key? n
  count += cl.locations.length
  if count > max
    n +=1; count = 0
  else
    # merge the locations with matching chromosomes
    cat_ranks[n][cl.chr] = cl unless cat_ranks[n].has_key? cl.chr
    cat_ranks[n][cl.chr] = cat_ranks[n][cl.chr].merge! cl
  end
end

# just for simplicity reorder so it's an array of location objects within the rank hash
ranked_patient_locations = {}
cat_ranks.each_pair.map { |rank, clhash| ranked_patient_locations[rank] = clhash.values if rank.eql? 0 }


## -- CONTROLS -- ##
# Get variations for controls in each location that patients also have variations
# Am not including all possible locations in the control file as that will greatly increase
# the MDR files and decrease possible hits
puts "Getting control variations."

ctrl_temp_dir = "#{cfg['output.dir']}/vcf/#{Utils.date}"
#FileUtils.rm_rf(ctrl_temp_dir) if File.exists? ctrl_temp_dir
FileUtils.mkpath(ctrl_temp_dir) unless File.exists? ctrl_temp_dir

mdr_temp_dir = "#{cfg['output.dir']}/mdr/#{Utils.date}"
#FileUtils.rm_rf(mdr_temp_dir) if File.exists? mdr_temp_dir
FileUtils.mkpath(mdr_temp_dir) unless File.exists? mdr_temp_dir

analysis_dir = "#{cfg['mdr.analysis.dir']}/#{Utils.date}"
FileUtils.rm_rf(analysis_dir) if File.exists? analysis_dir
FileUtils.mkpath(analysis_dir)

rank_file_locs = "#{cfg['output.dir']}/rank/#{Utils.date}"
FileUtils.rm_rf(rank_file_locs) if File.exists? rank_file_locs
FileUtils.mkpath(rank_file_locs)


order = []
colnames = []
## pull out subsets of the VCF files first ##
ranked_patient_locations.sort.map do |rank, locations|
  next if File.exists? "#{rank_file_locs}/Rank#{rank}-ctrl.txt"
  mdr = SimpleMatrix.new()
  locations.sort.map do |cvp|
    order << cvp.chr
    chr_vcf_file = "#{cfg['control.var.loc']}/#{control_vcf[cvp.chr]}"

    cvp.locations.each do |loc|
      column_name = "#{cvp.chr}:#{loc}"

      ctrl = COGIE::ControlSample.new(chr_vcf_file, {:tabix => "#{cvp.chr}:#{loc}-#{loc}", :out => ctrl_temp_dir, :tabix_path => cfg['tabix.path']})
      vars = ctrl.parse_variations(['SNP']) # NOTE: only dealing in SNPs.  Changing this means the columns should be more descriptive
      mdr.rownames = ctrl.samples.map { |s, v| "Sample-#{s}" } if mdr.rownames.empty?

      # Sometimes there's no such position in the control sample, have to then assume that the control is GT=0/0 (Major allele for the given position)
      vars.each do |var|
        if (var.pos.eql? loc)
          mdr.add_column(column_name, var.samples.map { |s, v| COGIE::Func.mdr_genotype(v['GT']) })
        else
          mdr.add_column(column_name, Array.new(var.samples.length).map { |e| e = '0' })
        end
      end
      ## Sometimes the control files do not list that variation.
      ## In this case presume GT = 0
      if vars.empty?
        col = Array.new(mdr.size[0])
        mdr.add_column(column_name, col.map { |e| e = 0 })
      end
    end
  end
  class_col = Array.new(mdr.size[0])
  mdr.add_column('Class', class_col.map { |e| e = 0 })
  colnames = mdr.colnames
  mdr.write("#{rank_file_locs}/Rank#{rank}-ctrl.txt")
end


## -- PATIENTS -- ##

# Patient directories where each chromosome file is kept
puts "Getting patient variations."
pt_matrix = SimpleMatrix.new
pt_matrix.colnames = colnames

ranked_patient_locations.sort.map do |rank, locations|
  # per patient
  patient_dirs.each do |dir|
    puts "READING #{dir}"
    rowname = File.basename(dir)
    pt_matrix.add_row(rowname, Array.new(colnames.length).map { |e| e = 'NA' })

    locations.sort.map do |cvp| # this is important to maintain the sort order that was output in the Rank files above
      cvp.locations.each do |loc|
        colname = "#{cvp.chr}:#{loc}"


        fcfile = "#{dir}/Chr#{cvp.chr}.func"
        gt = COGIE::PVUtil.find_patient_variation(fcfile, loc)

        # Genotype will be nil or an empty string if the variation was not a SNP
        # NOTE: Currently we're only dealing with SNPs
        if gt.nil? or gt.eql? ""
          pt_matrix.add_element(rowname, colname, "0")
        else
          pt_matrix.add_element(rowname, colname, COGIE::Func.mdr_genotype(gt))
        end
      end
    end
  end

  ## Output the matrix of patients to the appropriate RANK file
  pt_matrix.update_column('Class', Array.new(pt_matrix.size[0]).map { |e| e = '1' }) # Class column, 1 = patient so update for all patients
  rankfile = "#{rank_file_locs}/Rank#{rank}-ctrl.txt"
  mdrfile = "#{mdr_temp_dir}/Rank#{rank}.mdr"
  FileUtils.copy(rankfile, "#{mdrfile}")
  puts "Writing #{mdrfile}"
  File.open(mdrfile, 'a') { |f|
    pt_matrix.rows.each_with_index do |row, i|
      f.write( "#{pt_matrix.rownames[i]}\t" + row.join("\t") + "\n")
    end
  }
end

