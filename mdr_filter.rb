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

def setup_output_dirs(cfg)
  # Don't want to regen the vcf/mdr directory more often than necessary as these files can take the longest to generate
  ctrl_temp_dir = "#{cfg['output.dir']}/vcf/#{Utils.date}"
  FileUtils.mkpath(ctrl_temp_dir) unless File.exists? ctrl_temp_dir

  mdr_temp_dir = "#{cfg['output.dir']}/mdr/#{Utils.date}"
  FileUtils.mkpath(mdr_temp_dir) unless File.exists? mdr_temp_dir

  analysis_dir = "#{cfg['mdr.analysis.dir']}/#{Utils.date}"
  FileUtils.rm_rf(analysis_dir) if File.exists? analysis_dir
  FileUtils.mkpath(analysis_dir)

  rank_file_locs = "#{cfg['output.dir']}/rank/#{Utils.date}"
  FileUtils.rm_rf(rank_file_locs) if File.exists? rank_file_locs
  FileUtils.mkpath(rank_file_locs)

  return [ctrl_temp_dir, mdr_temp_dir, analysis_dir, rank_file_locs]
end

## Rank the patient locations based on the locations pulled from the filter file
def rank_locations(cfg, patient_locations, ranges)
  puts "Creating ordered ranks"
  ranked_patient_locations = Hash[ranges.each_with_index.map { |e, i| [i, nil] }]
  ranges.each_with_index do |rl, i|
    range = rl[0]; chr = rl[1]
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

  # just for simplicity, reorder so it's an array of location objects within the rank hash
  ranked_patient_locations = {}
  cat_ranks.each_pair.map { |rank, clhash| ranked_patient_locations[rank] = clhash.values }

  return ranked_patient_locations
end

# Instead create a random sampling
def sample_locations(cfg, patient_locations, ranges)
  puts "Creating randomly sampled ranks"
  max = Float(cfg['mdr.max'])

  locations_by_chr = {}
  ranges.each do |rl|
    range = rl[0]; chr = rl[1]
    next unless patient_locations.has_key? chr
    pt_list = patient_locations[chr]
    pt_list = pt_list.select { |e| range.include? e }
    cl = COGIE::Locations.new(pt_list, chr)

    locations_by_chr[chr] = cl unless locations_by_chr.has_key? chr
    locations_by_chr[chr] = locations_by_chr[chr].merge! cl
  end
  locations_by_chr = locations_by_chr.values
  total_locations = 0
  locations_by_chr.each { |e| total_locations += e.locations.length }

  ranked_locations = {}
  (0..(total_locations/max).floor).each { |r| ranked_locations[r] = [] }
  ranked_locations.each_key do |rank|
    samples = {}
    (0..max).each do |count|
      s = locations_by_chr.sample.random_location
      samples[s.chr] = s unless samples.has_key? s.chr
      samples[s.chr] = samples[s.chr].merge! s
    end
    ranked_locations[rank] = samples.values
  end
  return ranked_locations
end

############################
### ---- START MAIN ---- ###
############################
if ARGV.length < 1
  usage =<<-USAGE
Usage: #{$0} <configuration file> <random OPTIONAL>
  - Configuration file is REQUIRED. See the cogie.config.example file.
  - random parameter is OPTIONAL. Default is to create mdr file in ordered ranking based on the provided ranked list.
  USAGE
  puts usage
  exit 2
end

## Configuration file is expected as input.  Read see resources/cogie.config.example
cfg = YAML.load_file(ARGV[0])

(ctrl_temp_dir, mdr_temp_dir, analysis_dir, rank_file_locs) = setup_output_dirs(cfg)

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
      raise "ERROR: Patient directories missing. Please rerun patient file indexing script."
    end
    patient_dirs << pdir
  end
end

if patient_dirs.empty?
  raise "ERROR: Patient directories missing. Please check that directories and .func files are available."
end


## Load the locations that were identified as being in the patient files
loc_file = "#{cfg['patient.var.loc']}/chr_locations.txt"
patient_locations = {}
File.open(loc_file, 'r').each_line do |line|
  line.chomp!
  next if line.start_with? "#"
  line = line.split("\t")
  chr = line.slice!(0)
  #next if chr.eql?'X' or chr.eql?'Y' or chr.eql?'MT'
  patient_locations[chr] = line[1..-1].map! { |e| Integer(e) }
end
## Forget X/Y for now it's complicating things
patient_locations.delete_if { |k, v| k.match(/X|Y|MT/) }


## Rank the patient locations based on the locations pulled from the filter file
# Either in order (ranked) or random (sampled)
if ARGV[1] and ARGV[1].eql? 'random'
  sample_locations(cfg, patient_locations, ranked_locations)
else
  ranked_patient_locations = rank_locations(cfg, patient_locations, ranked_locations)
end


## -- CONTROLS -- ##
# Get variations for controls in each location that patients also have variations
# Am not including all possible locations in the control file as that will greatly increase
# the MDR files and decrease possible hits
puts "Getting control variations."
matrix_sizes = []
columns_per_rank = Hash[ranked_patient_locations.each.map { |r, l| [r, []] }]


## pull out subsets of the VCF files first ##
columns = 0
ranked_patient_locations.sort.map do |rank, locations|
  puts "Rank #{rank}: #{locations.length} locations"

  "#{rank_file_locs}/Rank#{rank}-ctrl.txt"

  next if File.exists? "#{rank_file_locs}/Rank#{rank}-ctrl.txt"
  mdr_matrix = SimpleMatrix.new()


  locations.sort.map do |cvp|

    chr_vcf_file = "#{cfg['control.var.loc']}/#{control_vcf[cvp.chr]}"

    column_lengths = 0
    cvp.locations.each do |loc|
      column_name = "#{cvp.chr}:#{loc}"

      ctrl = COGIE::ControlSample.new(chr_vcf_file, {:tabix => "#{cvp.chr}:#{loc}-#{loc}", :out => ctrl_temp_dir, :tabix_path => cfg['tabix.path']})
      vars = ctrl.parse_variations(['SNP']) # NOTE: only dealing in SNPs.  Changing this means the columns should be more descriptive
      mdr_matrix.rownames = ctrl.samples.map { |s, v| "Sample-#{s}" } if mdr_matrix.rownames.empty?

      vars.each do |var|
        if (var.pos.eql? loc) # sometimes when there's no position at that exact location the next nearest one is returned.
          mdr_matrix.add_column(column_name, var.samples.map { |s, v| COGIE::Func.mdr_genotype(v['GT']) })
        else
          mdr_matrix.add_column(column_name, Array.new(var.samples.length).map{ |e| e = '0' })
        end
      end
      ## Sometimes the control files do not list that variation.
      ## In this case presume GT = 0
      if vars.empty?
        col = Array.new(mdr_matrix.size[0])
        mdr_matrix.add_column(column_name, col.map! { |e| e = 0 })
      end

      unless mdr_matrix.columns.length >= column_lengths+1
        raise "Columns added incorrectly at #{loc}"
      end
      column_lengths = mdr_matrix.columns.length
    end
  end

  class_col = Array.new(mdr_matrix.size[0])
  mdr_matrix.add_column('Class', class_col.map { |e| e = 0 })

  puts mdr_matrix.size.join(", ")
  col_count = mdr_matrix.size[1]-1
  mdr_matrix.rows.each_with_index do |row, i|
    if row.length != col_count
      puts "#{i} #{mdr_matrix.rownames[i]}: #{row.length}"
      #raise "Matrix columns for control variations in #{rank} are not all the same length. Failed at row #{i} Exiting."
    end
  end

  columns_per_rank[rank] = mdr_matrix.colnames
  mdr_matrix.write("#{rank_file_locs}/Rank#{rank}-ctrl.txt", :rownames => false)
end


## -- PATIENTS -- ##
# Patient directories where each chromosome file is kept
puts "Getting patient variations."
ranked_patient_locations.sort.map do |rank, locations|
  pt_matrix = SimpleMatrix.new
  pt_matrix.colnames = columns_per_rank[rank]

  puts "Rank #{rank}"
  # per patient
  patient_dirs.each do |dir|
    puts "READING #{dir}"
    rowname = File.basename(dir)
    pt_matrix.add_row(rowname, Array.new(pt_matrix.colnames.length).map { |e| e = 'NA' })

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

  pt_matrix.rows.each_with_index do |row, i|
    if row.length != columns_per_rank[rank].length
      puts "#{i} #{pt_matrix.rownames[i]}: #{row.length}"
#      raise "Matrix columns for control variations in #{rank} at row #{i} are not all the same length. Exiting."
    end
  end

  rankfile = "#{rank_file_locs}/Rank#{rank}-ctrl.txt"
  mdrfile = "#{mdr_temp_dir}/Rank#{rank}.mdr"
  FileUtils.copy(rankfile, mdrfile)
  FileUtils.chmod(0776, mdrfile)
  puts "Writing #{mdrfile}"
  File.open(mdrfile, 'a') { |f|
    pt_matrix.rows.each_with_index do |row, i|
      f.write(row.join("\t") + "\n")
    end
  }

end

