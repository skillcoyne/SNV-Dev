# Post MDR there should be sets of SNPs
# Need to map the SNPs back to genes in order to have gene sets to look at
# Results in lists of genes.  Those genes should continue to keep the scores
# that came from the MDR for the snps.  Possibly if there are multiple SNPs in
# a gene the gene score should reflect it.
require 'yaml'
require 'faraday'
require 'mysql'

# Read in the R summary file (for now) to collect the SNP sets


# Take a SNP and map it
#mysql --user=genome --host=genome-mysql.cse.ucsc.edu -A -D hg19 -e '
#select
# K.proteinID,
# K.name,
# S.name,
# S.avHet,
# S.chrom,
# S.chromStart,
# K.txStart,
# K.txEnd
#from snp130 as S
#left join knownGene as K on
# (S.chrom=K.chrom and not(K.txEnd+60000<S.chromStart or S.chromEnd+60000<K.txStart))
#where
# S.name in ("rs25","rs100","rs75","rs9876","rs101")'
ucscSQL=<<SQL
select
  K.geneName,
  K.name,
  S.name,
  S.avHet,
  S.chrom,
  S.chromStart,
  K.txStart,
  K.txEnd
from snp130 as S
  left join refFlat as K on
    (S.chrom=K.chrom and not(K.txEnd+60000<S.chromStart or S.chromEnd+60000<K.txStart))
where
  S.name in ("rs25","rs100","rs75","rs9876","rs101")'
SQL

#mysql --user=genome --host=genome-mysql.cse.ucsc.edu -A -D hg19 -e '
conn = Mysql.new('genome-mysql.cse.ucsc.edu', 'genome', '', 'hg19')
rs = con.query(SQL)
puts YAML::dump rs
#rs.each_hash { |h| puts h['name']}
conn.close


# There are also services (KAVIAR) that could profile the SNPs with additional evidence (scores?)


