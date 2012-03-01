require 'yaml'
require 'faraday'
require_relative 'lib/Annotation/bio_entity'
require_relative 'lib/Annotation/gene'
require_relative 'lib/Annotation/pathway'
require_relative 'lib/pathway_commons'


id_list = ["BTS",
           "SCN1A",
           "SCN2A",
           "SCN1B",
           "GABRG2",
           "GABRA1",
           "KCNQ2",
           "KCNQ3",
           "KCNA1",
           "CLCN2"]


pc = PathwayCommons.new

pathways = pc.get_pathways_by_genes([Gene.new(:id => "BRCA1", :type => "Gene Symbol"),
                                     Gene.new(:id => "BTS", :type => "Gene Symbol")])

pathways.each_key do |gene|
  puts "Gene #{gene.id}:\n"
  puts "\tNo pathways" unless pathways[gene].length > 0
  pathways[gene].each do |p|
    puts "\t#{p.id} #{p.name} #{p.database}\n"
  end
end