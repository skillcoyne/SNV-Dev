require 'rubygems'
require 'yaml'


mv_file = "data/masterVarBeta-examples.tsv"

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

columns = Array.new
File.open(mv_file, "r").each_line do |line|

  line = line.chomp

  next if line =~ /^#/
  data = line.split(/\t/)
  next if data.size < 12

  if line =~/^>/
    columns = data
    next
  end

  (locus, chrom, locstart, locend, varType, seqA, seqB, geneA, geneB) = data.values_at(0, 2, 3, 4, 6, 8, 9, 25, 26)

  if (varType =~ /snp/)
    puts "#{locus}, #{chrom}, #{locstart}, #{locend}, #{varType}, #{seqA}, #{seqB}, #{geneA}\n"

  end



end




