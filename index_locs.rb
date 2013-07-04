require 'fileutils'
require 'yaml'
require_relative 'lib/cogie'



cfg = YAML.load_file(ARGV[0])

patients_file = cfg['patient.vcf']
vcf_name = File.basename(patients_file, '.vcf')

outdir = "#{cfg['output.dir']}/#{vcf_name}"

puts outdir

FileUtils.mkpath(outdir)

patient_ids = []
colnames = []
puts "Reading #{patients_file}"
File.open(patients_file, 'r').each_line do |line|
  if line.match(/#CHROM/)
    colnames = line.split("/t")
    patient_ids = colnames[9..colnames.size-1]
  end

  vcf = COGIE::VCF.new(line, patient_ids)
  next if vcf.chr.nil?

  out_file = "#{outdir}/chr#{vcf.chr}.vcf"

  unless File.exists?out_file
    puts "Starting #{out_file}"
    File.open(out_file, 'w'){ |f| f.write(colnames.join("\t") + "\n") }
  end

  File.open(out_file, 'a') { |f| f.write(line) }


end


