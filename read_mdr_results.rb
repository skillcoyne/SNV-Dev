require 'biomart'
require 'yaml'


def query_ensembl(regions = [])
  raise "Chromosome region(s) array required" if regions.empty?
puts regions
  sr = $hsgene.search(
      :filters => {'chromosomal_region' => regions, 'status' => ['KNOWN']},
      :attributes => ['ensembl_gene_id', 'external_gene_id', 'entrezgene'], #, 'ensembl_peptide_id' 'go_id', 'name_1006', 'namespace_1003'],
      :process_results => true
  )
  return sr
end

#file = ARGV[0]
biomart = Biomart::Server.new("http://www.ensembl.org/biomart")
$hsgene = biomart.datasets['hsapiens_gene_ensembl']

dir = "/Users/sarah.killcoyne/Data/COGIE/analysis/JME/0-50000/high-rank"
files = Dir["#{dir}/*.txt"]

puts files
puts "-------"

processed = files.select{|e| e.match(/-genes/) }
files.delete_if{|e| e.match(/-genes/) }
processed.map!{|e| e.sub("-genes", "") }

files.select!{|e| processed.index(e).nil?  }

files.each do |file|
  puts file

  path = File.absolute_path(file.sub(File.basename(file), ""))
  output_file = "#{path}/#{File.basename(file, '.txt')}-genes.txt"

  fout = File.open(output_file, 'w')

  File.open(file, 'r').each_with_index do |line, index|
    sleep 3 if index % 10 == 0   ## so that biomart doesn't get angry

    line.chomp!

    if index == 0 and !line.match(/modelAttributes/)
      warn "This is not an 'all models' file from MDR. Exiting"
      exit
    end
    next if line.empty? or line.match(/modelAttributes/)
    model_info = line.split("\t")

    ids = model_info[0]
    score = model_info[1]
    k = ""

    regions = []
    if ids.include? ","
      ids.split(",").each do |s|
        (chr, location) = s.split(":")
        regions << "#{chr}:#{location}:#{location}"
      end
      k = regions.length
    else # singles -- IGNORE FOR NOW
      (chr, location) = ids.split(":")
      regions << "#{chr}:#{location}:#{location}"
      k = 1
    end
    next if regions.empty?

    sr = $hsgene.search(
        :filters => {'chromosomal_region' => regions, 'status' => ['KNOWN']},
        :attributes => ['ensembl_gene_id', 'external_gene_id', 'entrezgene'],
        :process_results => true );

    next if sr.nil?

    fout.write ["#{k}", ids, score].join("\t") + "\n"
    sr.each do |r|
      fout.write "\t" + [ r['external_gene_id'], r['ensembl_gene_id'], r['entrezgene'] ].join("\t") + "\n"
    end

  end
  fout.close
  puts "#{output_file} written."
end

