require_relative 'lib/utils'
require_relative 'lib/ensembl_info'
require_relative 'lib/cogie_patient'

$cfg_defaults = {
    ## Ranked filter list
    'ranked.list' => '/<path to ranked gene|location list file>',

    # Gene locations
    'gene.loc' => '/<path to gene location file>',

    # Control
    'control.var.loc' => '/<path to control variation files>',

    # Patients
    'patient.var.loc' => '/<path to patient variation files>',

    # MDR
    'mdr.K' => 2,
    'mdr.max' => 50,
    'mdr.analysis.dir' => '/<ouptut path for R files>/',

    # OAR Cluster
    'oar.core' => 1,
    'oar.walltime' => 1,
    'oar.notify' => 'mail:skillcoyne\@gmail.com'
}


def load_filter_locations(filterfile, gi)
  locations = []

  File.open(filterfile, 'r').each_with_index do |line, index|
    line.chomp!
    cols = line.split("\t")
    # location
    if cols[0].match(/^\d+/)
      chr_start = Integer(cols[0])
      chr_end = Integer(cols[1])
      locations << [chr_start, chr_end]
    else # gene
      gene = cols[0]
      raise Exception, "ENSEMBL gene identifiers are required currently, please translate gene names in your filter file first (#{gene})" unless gene.match(/ENSG\d+/)
      info = gi.get_info(gene)
      locations << [info[:start], info[:end]] unless info.nil?
    end
  end
  return locations
end



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

ranked_locations = load_filter_locations(filter_file, info)
puts ranked_locations.length
#ranked_locations.each do |loc|
#  puts loc.join(",")
#end




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

# Get variations for controls in each location
puts "Getting control variations."
puts "TODO...control data resides on GAIA..."
Dir.foreach(cfg['control.var.loc']) do |entry|
  next if entry.match(/^\./)
  file = "#{cfg['patient.var.loc']}/#{entry}"

  ctrl = COGIE::ControlSample.new(file)

end
