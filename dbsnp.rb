require 'yaml'

record = 0
snps_by_gene = Hash.new
snps_by_chr = Hash.new
(chr, genes) = nil
File.open("data/dbsnp_all.txt", 'r').each_with_index do |line, index|
  line = line.chomp
  record = 1 if line =~ /^\d+: \w+  \[Homo sapiens\]$/
  record = 0 if line =~ /^CHROMOSOME BASE POSITION/

  chr = line.sub('CHR=', '') if line.start_with? 'CHR='
  genes = line.sub('GENE=', '').split(',') if line.start_with? 'GENE='

  if record == 0 and index > 1
    snps_by_chr[chr] = 0 unless snps_by_chr.has_key? chr
    snps_by_chr[chr] = snps_by_chr[chr] + 1

    genes.each do |gene|
      snps_by_gene[gene] = 0 unless snps_by_gene.has_key? gene
      snps_by_gene[gene] = snps_by_gene[gene] + 1
    end
  end
end

gene_counts = Hash.new
File.open("data/dbsnp_snp_by_gene.txt", 'w') { |f|
  f.write("Gene\tSNPs\n")
  snps_by_gene.each_pair do |gene, snps|
    f.write "#{gene}\t#{snps}\n"
    gene_counts[snps] = 0 unless gene_counts.has_key? snps
    gene_counts[snps] = gene_counts[snps] + 1
  end
}

File.open("data/dbsnp_gene_counts.txt", 'w') { |f|
  f.write("SNPs\tGeneCounts\n")
  gene_counts.each_pair do |snps, gene_count|
    f.write "#{snps}\t#{gene_count}\n"
  end
}


File.open("data/dbsnp_snp_by_chr.txt", 'w') {|f|
  f.write("Chr\tSNPs\n")
  snps_by_chr.each_pair do |chr, snps|
    f.write "#{chr}\t#{snps}\n"
  end
}

