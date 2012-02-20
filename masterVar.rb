require 'rubygems'
require 'yaml'

# masterVar file header
#   0     1       2           3     4   5         6       7         8           9           10                  11
# >locus	ploidy	chromosome	begin	end	zygosity	varType	reference	allele1Seq	allele2Seq	allele1VarScoreVAF	allele2VarScoreVAF
#   12                  13                  14                15                16              17              18          19
#   allele1VarScoreEAF	allele2VarScoreEAF	allele1VarQuality	allele2VarQuality	allele1HapLink	allele2HapLink	allele1XRef	allele2XRef
#   20                  21                22                23                        24              25          26          27
#   evidenceIntervalId	allele1ReadCount	allele2ReadCount	referenceAlleleReadCount	totalReadCount	allele1Gene	allele2Gene	pfam
#   28        29            30            31                      32            33                          34
#   miRBaseId	repeatMasker	segDupOverlap	relativeCoverageDiploid	calledPloidy	relativeCoverageNondiploid	calledLevel
#   35                                36                  37      38      39      40                  41
#   relativeCoverageSomaticNondiploid	somaticCalledLevel	bestLAF	lowLAF	highLAF	allele1ReadCount-N1	allele2ReadCount-N1
#   42                          43                44                      45              46          47            48
#   referenceAlleleReadCount-N1	totalReadCount-N1	locusDiffClassification	somaticCategory	somaticRank	somaticScore	somaticQuality

#mv_file_loc = "masterVar_file_locs.txt"
mv_file_loc = ARGV[0]
break "File name with locations of masterVar files expected\n" unless File.file?(mv_file_loc) and File.exists?(mv_file_loc)

mv_files = File.open(mv_file_loc, 'r').readlines

samples = Hash.new
mv_files.each do |f|
  samples[File.basename(f, File.extname(f))] = Hash.new
end

all_snvs = Hash.new

mv_files.each do |mv_file|
  mv_file = mv_file.chomp
  puts "Reading #{mv_file}\n"

  sample_name = File.basename(mv_file, File.extname(mv_file))

  columns = Array.new
  snvs = Hash.new
  File.open(mv_file, "r").each_line do |line|
    line = line.chomp

    # skip the header information and make sure you aren't dealing with that one empty line with tabs in it
    next if line =~ /^#/
    data = line.split(/\t/)
    next if data.size < 12

    # column line starts with >
    if line =~/^>/
      columns = data
      next
    end

    (locus, chrom, locstart, locend, varType, seqA, seqB, geneA, geneB) = data.values_at(0, 2, 3, 4, 6, 8, 9, 25, 26)

    # only interested in snps
    if (varType =~ /snp/)
      snp = "#{chrom}-#{locstart}"
      all_snvs[snp] = nil
      snvs[snp] = 1
    end

    samples[sample_name] = snvs
  end
end

mdrFile = File.open("mdr_data.txt", 'w')

mdrFile.write "\t#{all_snvs.keys.join('\t')}\tClass\n"

all_snvs.each_key do |snv|
  samples.each_key do |smpl|
    samples[smpl][snv] = 0 unless samples[smpl].has_key?(snv)
  end
end

samples.each_pair do |smpl, snv_list|
  line = "#{smpl}\t"
  all_snvs.each_key do |snv|
    line = line + "#{snv_list[snv]}\t"
  end
  mdrFile.write "#{line}#{rand(2)}\n"
end



#puts YAML::dump(samples)
