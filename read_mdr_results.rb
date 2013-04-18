require 'biomart'
require 'yaml'


def query_ensembl(regions = [])
  raise "Chromosome region(s) array required" if regions.empty?
  sr = $hsgene.search(
      :filters => {'chromosomal_region' => regions, 'status' => ['KNOWN']},
      :attributes => ['ensembl_gene_id', 'external_gene_id', 'ensembl_peptide_id', 'gene_biotype'],
      :process_results => true
  ).reject! { |e| e['ensembl_peptide_id'].nil? }

  results = {:genes => [""], :proteins => [""]}
  unless sr.nil?
    sr.select!{|e| e['gene_biotype'].eql?'protein_coding'}
    results[:genes] = sr.map{|e| e['ensembl_gene_id']}.uniq
    results[:proteins] = sr.map{|e| e['ensembl_peptide_id']}.uniq
  end

  return results
end

file = ARGV[0]

path = File.absolute_path(file.sub(File.basename(file), ""))
output_file = "#{path}/#{File.basename(file, '.txt')}-genes.txt"

biomart = Biomart::Server.new("http://www.ensembl.org/biomart")
$hsgene = biomart.datasets['hsapiens_gene_ensembl']


fout = File.open(output_file, 'w')
fout.write( ["k", "Model", "Score", "Genes", "Proteins"].join("\t") + "\n")

in_models = false
File.open(file, 'r').each_line do |line|
  line.chomp!
  if line.match(/Attributes	bal\. acc\. Model training/)
    in_models = true
    next
  end
  if line.match(/MDR finished/)
    break
  end

  if in_models
    next if line.empty?
    model_info = line.split("\t")

    ids = model_info[0]
    score = model_info[1]
    k = ""

    if ids.include? ","
      regions = []
      ids.split(",").each do |s|
        (chr, location) = s.split(":")
        regions.push("#{chr}:#{location}:#{location}")
      end

      results = query_ensembl(regions)
      k = regions.length
    else # singles
      (chr, location) = ids.split(":")
      results = query_ensembl(["#{chr}:#{location}:#{location}"])
      k = 1
    end

    print( [k, ids, score, results[:genes].join(","), results[:proteins].join(",")].join("\t") + "\n" )
    fout.write( [k, ids, score, results[:genes].join(","), results[:proteins].join(",")].join("\t") + "\n" )
  end
end

fout.close
puts "#{output_file} written."
