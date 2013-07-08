require_relative 'lib/utils'
require_relative 'lib/mdr_script'


### ---- START MAIN ---- ###
if ARGV.length < 1
  puts "Usage: #{$0} <configuration file>"
  exit 2
end


cfg = YAML.load_file(ARGV[0])

dirs = Utils.data_dir(cfg)
mdr_dir = dirs[:qual_dir]
analysis_dir = dirs[:analysis_dir]


jar = cfg['mdr.jar'] || "MDR.jar"


ms = MDRScript.new(mdr_dir, analysis_dir)
output_files = ms.write_script(:type => 'Java', :jar => jar, :k => cfg['mdr.K'], :models => cfg['mdr.models'])

#output_files.each {|f| ms.run_script(f, cfg['oar.core'], cfg['oar.walltime'])}
