require 'yaml'

class Utils

  def self.date
    time = Time.new
    return time.strftime("%d%m%Y")
  end

  def self.check_config(cfg_file, cfg_def, optional_keys = [])
    puts "Using #{cfg_file} config file"
    cfg = YAML.load_file(cfg_file)

    optional_keys.each { |k| cfg_def.delete(k); cfg.delete(k) }
    if cfg.keys.sort!.eql? cfg_def.keys.sort!
      return YAML.load_file(cfg_file)
    else
      puts "Incorrect config file, expected keys:\n"
      puts YAML::dump cfg_def
      exit(1)
    end
  end


  def self.run_tabix(opts = {})
    (opts[:tabix_path].nil?) ? (tabix = "tabix") : (tabix = "#{opts[:tabix_path]}/tabix")

    # presume you have to change directory to make it write int he correct place...still waiting to test
      vcf_output = `#{tabix} #{@ct_file} #{opts[:tabix]}`
      raise StandardError, "tabix failed to run, please check that it is installed an available in your system path." unless vcf_output
    return vcf_output

  end



end
