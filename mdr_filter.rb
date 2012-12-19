require 'fileutils'

require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/cogie_patient'
require_relative 'lib/control_sample'

$cfg_defaults = {
    ## Ranked filter list
    'ranked.list' => '/<path to ranked gene|location list file>',

    # Gene locations
    'gene.loc' => '/<path to gene location file>',

    # Control
    'control.var.loc' => '/<path to control variation files>',

    # Patients
    'patient.var.loc' => '/<path to patient variation files>',

    # File output
    'output.dir' => '/tmp files',

    # MDR
    'mdr.K' => '<1-4>',
    'mdr.max' => '<25-4000>',
    'mdr.analysis.dir' => '/<ouptut path for R files>/',

    # OAR Cluster
    'oar.core' => 1,
    'oar.walltime' => 1,
}


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
cfgfile = ARGV[0]


cfg = Utils.check_config(cfgfile, $cfg_defaults)
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

# Get variations for controls in each location
puts "Getting control variations."

ctrl_temp = "#{cfg['output.dir']}/vcf-tmp"
FileUtils.mkpath( ctrl_temp ) unless File.exists?(ctrl_temp)

ranked_locations.each_pair do |chr, list|
  next unless chr.eql? '12'
  file = "#{cfg['control.var.loc']}/#{control_vcf[chr]}"
  list.each do |loc|
    ctrl = COGIE::ControlSample.new(file, {:tabix => "#{chr}:#{loc[0]}-#{loc[1]}", :out => ctrl_temp})
  end
end

exit

# Get patient variations in each location
## One thing to note here, the first patient file read is going to determine the variations that get looked at
puts "Getting patient variations."

Dir.foreach(cfg['patient.var.loc']) do |entry|
  next if entry.match(/^\./)
  file = "#{cfg['patient.var.loc']}/#{entry}"
  #puts "Reading patient file #{file}..."

  begin
    cp = COGIE::COGIEPatient.new(file)
    mdr_vars = []
    ranked_locations.each do |loc|
      vars = cp.variations_by_location(loc[0], loc[1])
      puts "Variations for #{loc[0]} - #{loc[1]}: #{vars.length}"
      mdr_vars |= vars
      break if mdr_vars.length >= cfg['mdr.max']
    end

    puts "Variations for #{cp.patient}: #{cp.sum(:variations => true)}"
    puts "Genes with variations for #{cp.patient}: #{cp.sum(:genes => true)}"

    puts YAML::dump mdr_vars
    mdr_vars = mdr_vars[0..cfg['mdr.max']]

  rescue COGIE::FileFormatError => e
    warn "Error reading #{file}: #{e.message}"
    puts e.backtrace
  end

end

