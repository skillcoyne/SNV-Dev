require 'yaml'


counts_by_gene = Hash.new
genes_by_chr = Hash.new
File.open("data/mmc2.csv", 'r').each_line do |line|
  line = line.chomp

  next if line.start_with? "HUGO_Gene1"
  break if line.start_with? "FOOTNOTES"

  cols = line.split(',')
  (hugo, chr) = cols.values_at(0, 1)
  next if hugo.eql? 'unknown'

  chr = chr.to_s.sub('chr', '')

  counts_by_gene[hugo] = 1 unless counts_by_gene.has_key? hugo
  counts_by_gene[hugo] = counts_by_gene[hugo] + 1

  genes_by_chr[hugo] = chr

end

File.open("snps_by_gene.txt", 'w') { |f|
  counts_by_gene.each_pair do |gene, snps|
    chr = genes_by_chr[gene]
    f.write "#{gene}\t#{chr}\t#{snps}\n"
  end
}

