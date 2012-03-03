require 'rubygems'
require 'yaml'
require_relative 'lib/utils'
require_relative 'lib/gwa_control'

$config = "resources/gwa.config"

$config = ARGV[0] if ARGV.length > 0
cfg = Utils.check_config($config)

gwasim_results_dir = cfg['chr.output']
file_type = cfg['mdr.type']
# Case and snp numbers from control file
control = GWAControl.new(cfg['gwa.control'])

unless gwasim_results_dir && File.exists?(gwasim_results_dir) && File.directory?(gwasim_results_dir)
  raise IOError "#{gwasim_results_dir} doesn't exist or is not a directory."
end


# read snp files, add case column for MDR
Dir.foreach(gwasim_results_dir) do |entry|
  # unzip chr files
  next unless File.extname("#{gwasim_results_dir}/#{entry}").eql?".gz" or
      File.extname("#{gwasim_results_dir}/#{entry}").eql?".dat"
  system("gunzip #{gwasim_results_dir}/#{entry}")  if File.extname("#{gwasim_results_dir}/#{entry}").eql?".gz"
  next if "#{gwasim_results_dir}/#{entry}".eql?control.filename

  dat_file = entry.sub(".gz", "")
  chr = File.basename(dat_file, ".dat")

  # READ chr files/WRITE mdr files
  columns = control.total_snps(chr)
  puts "Total snps in #{dat_file}: #{columns}\n"
  puts dat_file if File.exists?"#{gwasim_results_dir}/#{dat_file}"
  mdr_file = File.open("#{gwasim_results_dir}/#{chr}.mdr", "w")

  # set up the columns for the mdr file
  snp_cols = Array.new
  snp_cols.push("Class") if file_type.eql?"R"
  (1..columns+1).each do |c|
    snp_cols.push("#{chr}_SNP#{c}")
  end
  puts "#{snp_cols.length} vs #{columns}"

  snp_cols.push("Class") if file_type.eql?"moore"
  mdr_file.write(snp_cols.join("\s") + "\n")

  # output the file for mdr
  case_ctrl = 0
  #puts "Cases: " + control.total_cases.to_s
  File.open("#{gwasim_results_dir}/#{dat_file}", 'r').each_line do |line|
    # this is slow, but it ensures that no unecessary columns are added
    lines = line.chomp.split("\s")
    if file_type.eql?"moore"
      lines.push(case_ctrl)
      mdr_file.write lines.join("\s") + "\n"
    else
      mdr_file.write "#{case_ctrl}\s" + lines.join("\s") + "\n"
    end

    (case_ctrl == 0)? (case_ctrl = 1): (case_ctrl = 0)
  end
  mdr_file.close

  #n = 0
  #File.open(mdr_file, "r").each_line do |l|
  #  puts "Reading: " + l.split("\s").length.to_s
  #  puts l
  #  n += 1
  #  break if n > 3
  #end


end


