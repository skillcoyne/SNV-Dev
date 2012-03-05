require 'rubygems'
require 'yaml'
require 'bio'
require 'savon'




# create a client for your SOAP service

client = Savon::Client.new("http://soap.genome.jp/v3.0/KEGG.wsdl")

client.wsdl.soap_actions
# => [:create_user, :get_user, :get_all_users]

# execute a SOAP request to call the "getUser" action
response = client.request(:get_pathways_by_genes,
  {'genes_id_list' => ["hsa:3653"]})



# Think Bio::KEGG may be dead
#serv = Bio::KEGG::API.new("http://soap.genome.jp/v3.0/KEGG.wsdl")

#results = serv.get_pathways_by_genes(["hsa:3653"])
#
#puts YAML::dump results

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