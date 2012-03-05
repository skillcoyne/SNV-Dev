# This class is used to parse the gene files from NCBI.  These include
# gene_info, gene2unigene, gene2ensembl etc.

class GeneInfo
  attr_accessor :gi_file

  # ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/GENE_INFO/Mammalia/Homo_sapiens.gene_info.gz
  def initialize(ncbi_gene_info_file)
    @gi_file = ncbi_gene_info_file
    puts "Using file #{@gi_file}"
  end

  #def download_file(to_dir)
  #  info_file = EasyNet.http_get(@gi_file)
  #  puts info_file
  #  # TODO finish....
  #end

  def get_all_by_tax_id(taxId)
    raise ArgumentError.new("Missing arguments, taxonomic id required.\n") unless taxId
    if @gi_file =~ /unigene/i && taxId =~ /\d+/
      raise ParseError.new("Unigene file does not use taxonomy ids.  Use two letter species id's.  Example: 'Hs' for human")
    end

    gene_list = []
    File.open(@gi_file, "r").each_line do |line|
      next if line =~ /^#/
      line = line.chomp
      a = line.split(/\t/)
      tax_id = a[0]
      next unless (tax_id.to_i == taxId.to_i)
      gene_list.push(line)
    end
    return gene_list
  end

  def get_all_unigene_by_species(sp)
    return get_all_by_tax_id("#{sp}.")
  end

  def get_gene_list_by_symbols
    list = []
    if (@gi_file =~ /gene_info/)
      File.open(@gi_file, "r").each_line do |line|
        line = line.chomp
        tax_id, entrezId, officialSymbol, locusTag, synonyms, dbX, chr, loc, desc, type, s, n, o, date = line.split(/\t/)
        list.push(officialSymbol)
      end
    else
      raise ArgumentError.new("Method 'get_by_gene' is only useful on the NCBI gene_info file")
    end
    return list
  end


  def get_by_gene(opts = {})
    raise ArgumentError.new("Missing arguments.\n") unless opts[:entrez] || opts[:symbol]
    if (@gi_file =~ /gene_info/)
      File.open(@gi_file, "r").each_line do |line|
        line = line.chomp
        tax_id, entrezId, officialSymbol, locusTag, synonyms, dbX, chr, loc, desc, type, s, n, o, date = line.split(/\t/)
        if ((opts[:entrez] && opts[:entrez].eql?(entrezId)) || (opts[:symbol].eql?(officialSymbol)))
          return {:tax_id => tax_id, :entrez_id => entrezId, :official_symbol => officialSymbol, :chr => chr, :desc => desc}
        end
      end
    else
      raise ArgumentError.new("Method 'get_by_gene' is only useful on the NCBI gene_info file")
    end
  end

  # for now it just filters by tax id, could add other filters later
  def create_filtered_file(opts = {})
    raise ArgumentError, ":tax_id, :output_file are required" unless opts[:tax_id] and opts[:output_file]

    File.open(opts[:output_file], 'w') { |out|
      File.open(@gi_file, "r").each_line do |line|
        next if line =~ /^#/
        line = line.chomp
        a = line.split(/\t/)
        tax_id = a[0]
        next unless (tax_id.to_i == opts[:tax_id].to_i)
        out.write("#{line}\n")
      end
    }

  end

end
 
