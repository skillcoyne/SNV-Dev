require 'yaml'

module COGIE

  class COGIEPatient
    @@header = "### PID: <number>\n### CALL: <script information>\n"
    @@colnames = [
        'CHROM', 'FROM', 'TO',
        'REF', 'ALLELES', 'TYPE',
        'CALLER_IDT', 'CALLER_OVL', 'READS',
        'QUAL', 'TARG_DIST', 'ALLELE',
        'AN', 'GT',
        'AR_FREQ', 'RR_FREQ',
        'VARDB_NAME', 'VARDB_FREQ', 'VARDB_INFO',
        'REGION_INFO', 'CALLER_INFO',
        'ENS_GENE', 'ENS_TRANSCRIPT', 'ENS_TRANSLATION',
        'STRAND', 'TRANSCRIPT_BIOTYPE', 'HGNC',
        'CCDS', 'REFSEQ',
        'DIST_5SS', 'DIST_3SS',
        'REGULATION_INFO', 'MUT_POS', 'CONSEQUENCE',
        'MUT_CDNA', 'MUT_PROT', 'PREDICTION']

    class<<self
      attr_accessor :warnings, :patient
    end

    attr_reader :genes, :patient

    def initialize(file)
      @pt_file = file
      @warnings = []
      @genes = {}

      check_format()
      parse_variations()
    end

    # Options: :variations, :genes
    def sum(opts = {})
      count = 0
      if opts[:variations]
        @genes.each_pair {|k,g| count += g.variations.length }
      elsif opts[:genes]
        count = @genes.keys.length
      end
      return count
    end

    def variations_by_location(from, to)
      vars = []
      @genes.each_value do |gene|
        gene.variations.each do |v|
          vars << v if (v.start_loc >= from and v.end_loc <= to)
        end
      end
      return vars
    end



    :private

    def parse_variations
      puts "Parsing #{@pt_file}..."
      File.open(@pt_file, 'r').each_with_index do |line, index|
        next unless index > 2

        next if line.start_with?"#" # the header lines are repeated throughout the file
        line.chomp!
        cols = line.split("\t")
        @warnings << "Row #{index} may be incorrectly formatted. Missing expected columns." if cols.length != @@colnames.length

        (chr, from, to) = cols[0..2]
        type = cols[5]; reads = cols[8]; genotype = cols[13]; gene = cols[21]

        gene = "unknown" if gene.eql?"."

        @genes[gene] = Gene.new(gene) unless @genes.has_key?gene
        @genes[gene].variation = Variation.new(chr, from, to, type, genotype)

      end
      puts "#{@pt_file} read."
    end

    def check_format
      patient = File.basename(@pt_file)
      patient.sub!(/\..*/, "")
      @patient = patient

      error = ""
      File.open(@pt_file, 'r').each_with_index do |line, index|
        line.chomp!
        line.sub!(/^#/, "") if index == 2
        error = "File is not in the expected format. Header missmatch. #{@@header} expected." if (index == 0 and !line.match(/^### PID:\t\d+$/))
        error = "File is not in the expected format. Header missmatch. #{@@header} expected." if (index == 1 and !line.match(/^### CALL:/))
        error = "#{error}\nFile column headers do not match expected columns:\n" + @@colnames.join("\t") if (index == 2 and !line.eql? @@colnames.join("\t"))
        error = "#{error}\nPatient files may have been mixed. Look at CALL lines." if (index > 1 and line.match(/^### CALL:/) and !line.match(/#{patient}/))
      end

      unless error.empty?
        raise FileFormatError, error
      end
    end
  end


  class Gene
    attr_reader :variations

    def initialize(name)
      raise ArgumentError, "Ensembl gene names expected" unless (name.match(/ENSG\d/) or name.eql?"unknown")
      @name = name
      @variations = []
    end

    def variation=(v)
      raise ArgumentError, "Variation class expected" unless v.is_a? COGIE::Variation
      @variations << v
    end
  end

  class Variation
    attr_accessor :chromosome, :start_loc, :end_loc, :type, :gt

    def initialize(*args)
      @chromosome = args[0]
      @start_loc = Integer(args[1])
      @end_loc = Integer(args[2])
      @type = args[3] if args[3]
      @gt = args[4] if args[4]
    end

  end


  class FileFormatError < StandardError
  end


end