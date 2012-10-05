require 'yaml'

class Utils

  def Utils.date
    time = Time.new
    month = time.month
    month < 10? (month = "0#{month}"): month
    day = time.day
    day < 10? (day = "0#{day}"): day

    return "#{time.year}#{month}#{day}"
  end

  def Utils.check_config(gwa_file)
    puts "Using #{gwa_file} config file"

    cfg = YAML.load_file(gwa_file)

    if cfg.keys.eql?$cfg_defaults.keys
      return cfg
    else
      puts "Incorrect config file, expected keys:\n"
      puts YAML::dump $cfg_defaults
      exit(1)
    end
  end


  $cfg_defaults = {
      #GWA
      'gwa.control' => '/<path to>/ control.dat',
      'gwa.seed' => 'some number',
      'chr.output' => '/<path to chr files>/',

      # MDR
      'mdr.type' => 'R or java',
      'mdr.K' => 2,
      'mdr.max' => 50,
      'mdr.analysis.dir' => '/<ouptut path for R files>/',

      # OAR Cluster
      'oar.core' => 1,
      'oar.walltime' => 1,
      'oar.notify' => 'mail:skillcoyne\@gmail.com'
  }


end