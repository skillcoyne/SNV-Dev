require 'yaml'

class GWAConfig

  def GWAConfig.check(gwa_file)
    puts "Using #{gwa_file} config file"

    cfg = YAML.load_file(gwa_file)

    if cfg.keys.eql?$defaults.keys
      return cfg
    else
      puts "Incorrect config file, expected keys:\n"
      puts YAML::dump $defaults
      exit(1)
    end
  end


  $defaults = {
      #GWA
      'gwa.control' => '/<path to>/ control.dat',
      'gwa.seed' => 'some number',
      'chr.output' => '/<path to chr files>/',

      # MDR
      'mdr.type' => 'R or moore',
      'mdr.K' => 2,
      'mdr.max' => 50,
      'mdr.analysis.dir' => '/<ouptut path for R files>/',

      # OAR Cluster
      'oar.dir' => '/<output directory for oar.sh files>/'
  }


end