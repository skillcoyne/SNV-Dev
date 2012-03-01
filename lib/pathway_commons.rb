require 'rubygems'
require 'faraday'
require 'json'
require 'yaml'

class PathwayCommons
  class << self;
    attr_accessor :baseURL, :requestURL, :version, :conn
  end

  #default
  def initialize()
    @baseURL = "http://www.pathwaycommons.org"
    @requestURL = "/pc/webservice.do"
    @version = "3.0"

    @conn = Faraday.new(:url => @baseURL) do |builder|
      builder.request :url_encoded
      builder.response :logger
      builder.adapter :net_http
    end
  end

  # Retrieves a hash of pathways by the given list of genes
  # Returns:
  #  { GeneSymbol => [ { :id => PathwayCommonsIdentifier, :name => PathwayName } ] }
  def get_pathways_by_genes(geneList = [])
    geneList.each do |geneSymbol|

      puts "req URL: #{@requestURL}, gene symbol #{geneSymbol}"

      response = @conn.get do |req|
        req.url @requestURL,
                req.params = {'version' => @version,
                              'cmd' => 'get_pathways',
                              'q' => "#{geneSymbol}",
                              'input_id_type' => 'GENE_SYMBOL'}
      end

      if response

        geneToPathways = Hash.new

        puts YAML::dump response
        #pathways = response.body.split(/\n/)

        #pathways.each do |pathway|
        #  pathway = pathway.chomp
        #  unless pathway =~ /^Database:ID/ || pathway =~ /.*(PHYSICAL_ENTITY_ID_NOT_FOUND|NO_PATHWAY_DATA)/ # no pathway data
        #    gene, pathName, pathType, pcId = pathway.split(/\s+/)
        #
        #    unless geneToPathways.has_key?geneSymbol
        #      geneToPathways[geneSymbol] = []
        #    end
        #    if pcId
        #      geneToPathways[geneSymbol].push(:id => pcId, :name => pathName)
        #    end
        #  end
        #end
      end
    end
    return geneToPathways
  end

  # options, these options specify the record information that can be requested from PathwayCommons
  # REQUIRED:
  # :id => A comma separated list of Pathway Commons unique identifiers
  # : output_type => See Pathway Commons for a list of output types (including biopax and binary_sif)
  # OPTIONAL:
  # : output_id_type => See Pathway Commons (including GENE_SYMBOL and ENTREZ_GENE)
  # Returns:
  #   The response string of the request or nil if no response
  def get_record_by_id(opt = {})
    unless opt[:id] && opt[:output_type]
      raise ArgumentError.new("Missing arguments. :id and :output_type required. :output_id_type and :output optional")
    end
    params = {'cmd' => 'get_record_by_cpath_id', 'q' => opt[:id],
              'output' => opt[:output_type]}
    params['output_id_type'] = opt[:output_id_type] if opt[:output_id_type]

    response = @conn.get do |req|
      req.url @requestURL,
              req.params = params
    end

    print YAML::dump response

    return response
  end

  # Calls get_record_by_id with the list of ides and the output_id_type set to 'toIdType'
  # Returns:
  #   The response string of the request or nil if no response
  def translate_ids(idList, toIdType)
    self.get_record_by_id(:id => idList.join(","), :output_type => "gsea", :output_id_type => toIdType)
  end


end