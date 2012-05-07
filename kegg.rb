require 'rubygems'
require 'yaml'
require 'bio'




serv = Bio::KEGG::API.new("http://soap.genome.jp/KEGG.wsdl")
results = serv.get_pathways_by_genes(["hsa:3569"])

puts YAML::dump results

#results = serv.get_best_neighbors_by_gene("eco:b0002", "bsu")

## case 0 : without filter
#results.each do |hit|
#  print hit.genes_id1, "\t", hit.genes_id2, "\t", hit.sw_score, "\n"
#end
#
## case 1 : select gene names and SW score only
#fields = [:genes_id1, :genes_id2, :sw_score]
#results.each do |hit|
#  puts hit.filter(fields).join("\t")
#end
#
## case 2 : also uses aligned position in each amino acid sequence etc.
#fields1 = [:genes_id1, :start_position1, :end_position1, :best_flag_1to2]
#fields2 = [:genes_id2, :start_position2, :end_position2, :best_flag_2to1]
#results.each do |hit|
#  print "> score: ", hit.sw_score, ", identity: ", hit.identity, "\n"
#  print "1:\t", hit.filter(fields1).join("\t"), "\n"
#  print "2:\t", hit.filter(fields2).join("\t"), "\n"
#end