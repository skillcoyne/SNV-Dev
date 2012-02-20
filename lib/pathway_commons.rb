require 'easy_net'
require 'net/http'
require 'json'


class PathwayCommons
  #Code here
  pathwayCommonsURL = 'http://www.pathwaycommons.org/pc/webservice.do'
  pc_version = "2.0"

  # Retrieves a hash of pathways by the given list of genes
  # Returns:
  #  { GeneSymbol => [ { :id => PathwayCommonsIdentifier, :name => PathwayName } ] }
  def PathwayCommons.get_pathways_by_genes(geneList = [])
    geneList.each do |geneSymbol|

      response = EasyNet.http_post(pathwayCommonsURL, {'cmd' => 'get_pathways', 'q' => "#{geneSym}",
                                          'input_id_type' => 'GENE_SYMBOL', 'version' => pc_version } )
      if response
        geneToPathways = {}
        pathways = response.body.split(/\n/)
        pathways.each do |pathway|
          pathway = pathway.chomp
          unless pathway =~ /^Database:ID/ || pathway =~ /.*(PHYSICAL_ENTITY_ID_NOT_FOUND|NO_PATHWAY_DATA)/ # no pathway data
            gene, pathName, pathType, pcId = pathway.split(/\s+/)

            unless geneToPathways.has_key?geneSymbol
              geneToPathways[geneSymbol] = []
            end
            if pcId
              geneToPathways[geneSymbol].push(:id => pcId, :name => pathName)
            end
          end
        end
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
  def PathwayCommons.get_record_by_id(opt = {})
    unless opt[:id] && opt[:output_type]
      raise ArgumentError.new("Missing arguments. :id and :output_type required. :output_id_type and :output optional")
    end
    params = {'cmd' => 'get_record_by_cpath_id', 'q' => opt[:id],
              'output' => opt[:output_type] }
    params['output_id_type'] = opt[:output_id_type] if opt[:output_id_type]
    return EasyNet.http_post(pathwayCommonsURL, params)
  end

  # Calls get_record_by_id with the list of ides and the output_id_type set to 'toIdType'
  # Returns:
  #   The response string of the request or nil if no response
  def translate_ids(idList, toIdType)
    get_record_by_id(:id => idList.join(","), :output_type => "gsea", :output_id_type => toIdType)
  end



end
