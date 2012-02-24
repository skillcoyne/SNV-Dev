require 'rubygems'
require 'yaml'
require_relative 'lib/gwa_control'

file_type = "moore" # moore or R

gwasim_results_dir = ARGV[0]
file_type = ARGV[1]

#gwasim_results_dir = "/home/skillcoyne/tools/GWAsimulator/test2"
unless gwasim_results_dir && File.exists?(gwasim_results_dir) && File.directory?(gwasim_results_dir)
  puts "Directory with GWASimulator results required\n"
  exit
end

# Case and snp numbers from control file
control = GWAControl.new("#{gwasim_results_dir}/control.dat")


diseasemodel = File.new("#{gwasim_results_dir}/diseasemodel.txt")
unless File.exists?diseasemodel
  puts "#{diseasemodel} does not exist."
  exit
end

# read snp files, add case column for MDR
Dir.foreach(gwasim_results_dir) do |entry|
  next unless File.extname("#{gwasim_results_dir}/#{entry}").eql?".gz" or
      File.extname("#{gwasim_results_dir}/#{entry}").eql?".dat"
  system("gunzip #{gwasim_results_dir}/#{entry}")  if File.extname("#{gwasim_results_dir}/#{entry}").eql?".gz"
  next if entry.eql?"control.dat"

  dat_file = entry.sub(".gz", "")
  chr = File.basename(dat_file, ".dat")

  columns = control.total_snps(chr)

  puts dat_file if File.exists?"#{gwasim_results_dir}/#{dat_file}"

  mdr_file = File.open("#{gwasim_results_dir}/#{chr}.mdr", "w")

  # set up the columns for the mdr file
  snp_cols = Array.new
  snp_cols.push("Class") if file_type.eql?"R"
  (1..columns+1).each do |c|
    snp_cols.push("#{chr}_SNP#{c}")
  end

  snp_cols.push("Class") if file_type.eql?"moore"
  mdr_file.write(snp_cols.join("\s") + "\n")

  # output the file for mdr
  case_ctrl = 0
  puts "Cases: " + control.total_cases.to_s
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


end