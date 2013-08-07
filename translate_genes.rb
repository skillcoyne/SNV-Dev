require 'fileutils'
require 'biomart'
require 'yaml'


if ARGV.length < 1
  warn "Gene list file required"
  exit
end

file = ARGV[0]
unless File.exists?file
  warn "File #{file} does not exist"
  exit
end

gene_type = "hgnc_symbol"
if ARGV[1]
  gene_type = ARGV[1]
end

genes = []
File.open(file, 'r').each_line { |line|
  line.chomp!
  genes << line unless line.length <=0
}


biomart = Biomart::Server.new("http://www.ensembl.org/biomart")
hsgene = biomart.datasets['hsapiens_gene_ensembl']


filters = {
    gene_type => genes,
}

attributes = [
    'ensembl_gene_id',
    'external_gene_id',
    'start_position',
    'end_position'
]

results = hsgene.search(
    :filters => filters,
    :attributes => attributes,
    :process_results => true
)

unless results.nil?

  ens_genes = results.map { |e| e['ensembl_gene_id'] }.uniq

  base = File.basename(file, ".txt")
  dir = File.dirname(file)

  File.open("#{dir}/#{base}-ens.txt", 'w') {|f|
    f.write ens_genes.join("\n")
  }

else
  puts "No results"
end

