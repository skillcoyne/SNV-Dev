require 'yaml'
require 'faraday'
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

pc.get_pathways_by_genes(["BTS"])

