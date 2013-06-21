module COGIE

  class FileFormatError < StandardError
  end

  class PVUtil
    @files = {}
    class << self # thought I was being clever and keeping the open filehandles around but doesn't seem to work, meh
      def open_file(filename)
        @files[filename] ||= File.open(filename, 'r')
      end
    end

    def self.find_patient_variation(file, location)
      fh = self.open_file(file)
      fh.each_with_index do |line, i|
        line.chomp!; next if line.start_with? "#"
        begin
          cf = COGIE::Func.parse_line(line)
          ## NOTE: in this case we are dealing only with SNPs
          if cf.from.eql? location
            return cf.genotype
          end
        rescue COGIE::FileFormatError => e
          warn "Error reading #{file} at line #{i}: #{e.message}"
        end
      end
      return nil
    end

  end

  ## This class is specific to the .func file format that was provided by Cologne.  If a different format
  ## like VCF is used then this just has to be switched out in the COGIEPatient class.
  class Func
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


    attr_reader :chr, :from, :to, :type, :reads, :genotype, :gene, :line

    def self.check_format(file)
      patient = File.basename(file).sub!(/\..*$/, "")

      error = ""
      File.open(file, 'r').each_with_index do |line, index|
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

    # If you really want in instantiate this way
    def self.parse_line(line)
      return self.new(line)
    end

    # / unphased  |  phased in VCF files. Since MDR isn't dealing in haplotypes we just need
    # a 0,1,2 for the diploid sequence
    # Func files add :  as well with no explanation so treat them identically for now
    def self.mdr_genotype(obj)
      if obj.is_a? String
        gt = obj
      elsif obj.is_a? self
        gt = obj.genotype
      else
        raise ArgumentError, "#{__method__} requires a genotype phased string (0/1) or a #{self.name} object. (#{obj} provided)"
      end

      if gt.nil? or gt.eql? ""
        return "NA"
      end

      (h1, h2) = gt.split(/:|\/|\|/)
      #gt.match(/(\d)[:|\/|\|](\d)/)
      #h1 = Integer($1); h2 = Integer($2)
      h2 = 0 if h2.nil?
      h1 = h1.to_i
      h2 = h2.to_i

      case # I think it's appropriate to report 0/1 as 1
        when h1+h2 == 0 # 0/0
          return 0
        when h1+h2 <= 2 # 0/1  or  1/1
          return 1
        when h1+h2 >= 3 # 1/2  or 2/2
          return 2
      end
    end


    def initialize(line)
      raise FileFormatError, "Columns do not match (#{@@colnames.length})" unless line.split("\t").length.eql? @@colnames.length
      parse(line)
    end


    :private

    def parse(line)
      line.chomp!
      @line = line
      cols = line.split("\t")

      (@chr, from, to) = cols[0..2]
      @type = cols[5]; reads = cols[8]; @genotype = cols[13]; @gene = cols[21]

      (reads.eql? "") ? (@reads = nil) : (@reads = Integer(reads))

      @from = Integer(from)
      @to = Integer(to)
      @gene = "unknown" if @gene.eql? "."

      raise ArgumentError, "Ensembl gene names expected" unless @gene.match(/ENSG\d|unknown/)
    end

  end

  # Specific to Wiktor's VCF format
  class VCF

    attr_accessor :chr, :pos, :id, :ref, :alt, :qual, :filter, :info, :format, :samples

    def initialize(line=nil, sample_names=nil, format_filter=nil)
      @info = {}
      @samples = {}
      parse_line(line, sample_names, format_filter) if line != nil
    end

    def parse_line(line, sample_names=nil, format_filter=nil)
      return nil if line.start_with? "#"

      cols = line.chomp.split("\t")
      raise "Line has no samples" if cols.size < 9

      (@chr, @pos, @id, @ref, @alt, @qual, @filter) = cols[0..6]
      @pos = @pos.to_i
      @qual = @qual.to_f

      @info = {}
      cols[7].split(";").each do |x|
        keyval = x.split("=", -1)
        if keyval.size == 2 # If it's key=value
          @info[keyval[0]] = keyval[1]
        else # Otherwise, it's just a flag
          @info[x] = ""
        end
      end

      @format = cols[8].split(":")

      samples = cols[9..cols.size-1]

      if sample_names == nil # Make the sample names just ["1", "2", ... , "num_samples}"
        sample_names = (1..samples.size).to_a.map { |i| i.to_s }
      elsif sample_names.size != samples.size
        raise "Unexpected number of samples (#{samples.size}) based on the provided sample names (#{sample_names.inspect})"
      end

      @samples = {}
      sample_names.each_with_index do |sample_name, si|
        i = si + 9 # index into columns
        sample_values = cols[i].split(":")
        warn "Expected number of sample values to be <= number of sample keys in FORMAT column Format=#{@format} but sample=#{cols[i]}" if sample_values.size > @format.size
        @samples[sample_name] = {}

        sample_values.each_with_index do |val, i|
          if i < @format.size
            key = @format[i]
            @no_qual = true unless @format[i].eql?'GT'
          else
            key = i
          end
          @samples[sample_name][key] = val
        end
        if format_filter
          @samples.delete(sample_name) unless @samples[sample_name].has_key?format_filter
        end
      end

      return true
    end

  end


end