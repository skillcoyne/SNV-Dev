require_relative 'lib/utils'
require_relative 'lib/mdr_script'


### ---- START MAIN ---- ###
if ARGV.length < 2
  puts "Usage: #{$0} <configuration file> <date as: YearMonthDay>"
  exit 2
end


#config_defaults = YAML.load_file("resources/cogie.config.example")
#cfg = Utils.check_config(ARGV[0], config_defaults, ['mdr.jar', 'tabix.path'])

cfg = YAML.load_file(ARGV[0])

date = ARGV[1]

mdr_temp_dir = "#{cfg['output.dir']}/mdr/#{date}"
analysis_dir = "#{cfg['mdr.analysis.dir']}/#{date}"

unless File.exists?(mdr_temp_dir) or File.exists?(analysis_dir)
  puts "The following directories may be missing. If so please rerun the mdr_filter.rb script:"
  puts "#{mdr_temp_dir}"
  puts "#{analysis_dir}"
  exit 2
end


jar = cfg['mdr.jar'] || "MDR.jar"

ms = MDRScript.new(mdr_temp_dir, analysis_dir)
output_files = ms.write_script(:type => 'Java', :jar => jar, :k => cfg['mdr.K'])
output_files.each {|f| ms.run_script(f, cfg['oar.core'], cfg['oar.walltime'])}
