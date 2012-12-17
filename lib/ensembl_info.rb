class EnsemblInfo
  @@format = "GeneID  GeneStart  GeneEnd  Chromosome [additional columns are allowed but ignored]"

  def initialize(file)
    @info_by_gene = {}
    parse(file)
  end

  def parse(file)
    puts file
    File.open(file, 'r').each_with_index do |line, index|
      next if index == 0 # first line
      line.chomp!
      cols = line.split("\t")
      raise ArgumentError, "#{file} is incorrectly formatted: #{@@format}" unless cols.length >= 4

      (gene, g_start, g_end, chr) = cols[0..4]
      @info_by_gene[gene] = {:start => g_start, :end => g_end, :chr => chr}
    end
  end

  def get_info(gene)
    return @info_by_gene[gene]
  end


end