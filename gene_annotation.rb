require 'yaml'
require_relative 'lib/gene_info'

gi = GeneInfo.new("../data/Homo_sapiens.gene_info")

puts YAML::dump gi.get_gene_list_by_symbols