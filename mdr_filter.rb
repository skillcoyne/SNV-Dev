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

unless cfg.has_key? 'patient.vcf' and cfg.has_key? 'qual.range' and cfg.has_key? 'output.dir'
  warn "Config file missing one or more required properties:  patient.vcf, qual.range, output.dir. Exiting."
  exit -1
end


# Get patient locations, output from index_cogie_patient
loc_file = "#{cfg['output.dir']}/#{File.basename(cfg['patient.vcf'], '.vcf')}/chr_locations.#{cfg['qual.range']}.txt"
patient_vcf_dir = "#{cfg['output.dir']}/#{File.basename(cfg['patient.vcf'], '.vcf')}"

unless File.exists? patient_vcf_dir and File.directory? patient_vcf_dir
  warn "Please run index_cogie_patient.rb first. Missing chromosome locations for #{cfg['patient.vcf']}"
  exit -1
end



mdr_file_dir = "#{cfg['output.dir']}/#{File.basename(cfg['patient.vcf'], '.vcf')}"

unless File.exists?mdr_file_dir and File.directory?mdr_file_dir
  warn "#{mdr_file_dir} does not exist, run index_cogie_patient.rb first."
  exit -1
end

mdr_file_dir = "#{mdr_file_dir}/#{cfg['qual.range']}"
FileUtils.mkpath(mdr_file_dir) unless File.exists?mdr_file_dir

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


## Load the locations that were identified as being in the patient files
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
if ARGV[2] and ARGV[2].eql? 'random'
  sample_locations(cfg, patient_locations, ranked_locations)
else
  ranked_patient_locations = rank_locations(cfg, patient_locations, ranked_locations)
end

# Get the patient ids for the matrix
patient_file = cfg['patient.vcf']
patient_ids = []
File.open(patient_file, 'r').each_line do |line|
  if line.match(/#CHROM/)
    line.chomp!
    cols = line.split("\t")
    patient_ids = cols[9..cols.size-1]
    break
  end
end

patient_dir = File.dirname(cfg['patient.vcf'])
patient_gz = Dir["#{patient_dir}/*.gz"].first


## -- VARIATION DATA -- ##
# Get variations for both controls and patients in each location that patients have variations
puts "Getting variations."

columns_per_rank = Hash[ranked_patient_locations.each.map { |r, l| [r, []] }]

tabix_path = cfg['tabix.path']
## pull out subsets of the VCF files first ##
columns = 0
ranked_patient_locations.sort.map do |rank, locations|
  puts "Rank #{rank}: #{locations.length} locations"

  mdr_matrix = SimpleMatrix.new

  ctrl_sample_names = []
  locations.sort.map do |cvp|

    chr_vcf_file = "#{cfg['control.var.loc']}/#{control_vcf[cvp.chr]}"

    ctrl_sample_names = COGIE::ControlSample.samples(chr_vcf_file) if ctrl_sample_names.empty?

    mdr_matrix.rownames = [ctrl_sample_names, patient_ids].flatten if mdr_matrix.rownames.empty?

    cvp.locations.each do |loc|
      puts "#{cvp.chr} #{loc}"
      ## Control Variations
      ctrl_vcf = Utils.run_tabix(:tabix => "#{chr_vcf_file} #{cvp.chr}:#{loc}-#{loc}")
      ctrl_genotypes = []
      unless ctrl_vcf.empty?
        ctrl_vcf.split("\n").each do |cline|
          vcf = COGIE::VCF.new(cline, ctrl_sample_names)

          if vcf.info['VT'].eql? 'SNP' and vcf.pos.eql? loc # Sometimes the nearest location is returned if there's no location in the VCF files that matches
            ctrl_genotypes = vcf.samples.map { |pt, vals| COGIE::Func.mdr_genotype(vals['GT']) }
          end
        end
      end

      ctrl_genotypes = ctrl_sample_names.map { |e| 0 } if ctrl_genotypes.empty?

      ## Patient Variations
      vcf = COGIE::VCF.new(Utils.run_tabix(:tabix => "#{patient_gz} #{cvp.chr}:#{loc}-#{loc}"), patient_ids)

      unless vcf.samples.nil?
        pt_genotypes = vcf.samples.map { |pt, vals| COGIE::Func.mdr_genotype(vals['GT']) }
        mdr_matrix.add_column("#{cvp.chr}:#{loc}", [ctrl_genotypes, pt_genotypes].flatten)
      end
    end
  end


  ## Add class column
  # 0 control, 1 patient
  sample_class = [ctrl_sample_names.map{|e| 0 }, patient_ids.map{|e| 1 }].flatten

  mdr_matrix.add_column('Class', sample_class)

  puts mdr_matrix.size.join(", ")
  col_count = mdr_matrix.size[1]
  mdr_matrix.rows.each_with_index do |row, i|
    if row.length != col_count
      raise "Matrix columns for control variations in #{rank} are not all the same length. Failed at row #{i} Exiting."
    end
  end

  puts "Rank #{rank}"
  puts mdr_matrix.size.join(",")

  columns_per_rank[rank] = mdr_matrix.colnames
  mdr_matrix.write("#{mdr_file_dir}/Rank#{rank}.mdr", :rownames => false)
end

