require 'yaml'

class Utils

  def self.date
    time = Time.new
    month = time.month
    month < 10? (month = "0#{month}"): month
    day = time.day
    day < 10? (day = "0#{day}"): day

    return "#{time.year}#{month}#{day}"
  end

  def self.check_config(cfg_file, cfg_def)
    puts "Using #{cfg_file} config file"
    cfg = YAML.load_file(cfg_file)
    if cfg.keys.sort!.eql?cfg_def.keys.sort!
      return cfg
    else
      puts "Incorrect config file, expected keys:\n"
      puts YAML::dump cfg_def
      exit(1)
    end
  end


end