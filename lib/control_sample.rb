require 'vcf'
require 'tmpdir'
require 'zlib'


module COGIE

  class Locations

    attr_reader :locations, :chr

    def initialize(list, chr)
      @locations = list; @chr = chr
      @locations = [] if (list.empty? or list.nil?)
    end

    def merge!(obj)
      raise ArgumentError, "Chromosomes don't match, cannot merge locations." unless @chr.eql? obj.chr
      @locations = @locations | obj.locations
      @locations.flatten
      @locations.uniq!
      @locations.sort!
      self
    end

    def random_location
      @sampled ||= []
      s = @locations.sample
      s = nil if @sampled.index(s) # don't return the same sample
      return COGIE::Locations.new([s], @chr)
    end


    def to_s
      "<#{self.class.name} Chr#{@chr}: locations:#{@locations.length}>"
    end

    def <=>(loc)
      if self.chr < loc.chr
        -1
      elsif self.chr > loc.chr
        1
      else
        0
      end
    end

  end

  ## The assumption is that these are VCF files
  class ControlSample

    attr_reader :name, :samples, :from, :to, :pos, :ct_file

    def self.samples(file)
      expected = ["#CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT"]
      Zlib::GzipReader.open(file).each_line do |line|
        if line.match(/#CHROM/)
          cols = line.split("\t")
          raise "Unexpected columns" unless cols[0..8].eql?expected
          return cols[9..cols.length]
        end
        break unless line.start_with?'#'
      end
      return []
    end

    # Uses samtools:tabix to read a VCF file given chromosome, from, to locations and returns the sample information for the given file
    # Params:
    # file - Control VCF file to read  REQUIRED
    # opts - {:tabix => 'chr:from-to', :out => writeable temp directory, default is System tmp}
    def initialize(file, opts = {})
      @ct_file = file
      if opts[:tabix]
        raise ArgumentError, "Chromosome location required for tabix in the format: '2:39967768-39967768'" unless (opts[:tabix].match(/(\d+|X|Y|MT):(\d+)-(\d+)/))
        @chr = $1; @from = $2; @to = $3
        (opts[:out]) ? (@tmp_output_dir = opts[:out]) : (@tmp_output_dir = Dir.tmpdir)
        run_tabix(opts)
      end
    end

    def parse_variations(types = [])
      types.map!{|e| e.upcase }
      sample = File.basename(@ct_file)
      sample.sub!(/\..*/, "")
      @name = sample
      @samples = []
      @pos = {}

      lines = []
      File.open(@ct_file, 'r').each_with_index do |line, index|
        line.chomp!
        next if line.start_with? "#"
        printf "." if (index > 0 and index%50 == 0)
        vcf = Vcf.new(line)
        next if (types.length > 0 and types.index(vcf.info['VT']).nil?)

        @samples = vcf.samples.keys if @samples.empty?
        @pos[vcf.pos] = vcf.samples
        lines << vcf
      end
      @samples.map! { |e| e.to_i }
      @samples.uniq!
      @samples.sort!
      return lines
    end


    :private
    #tabix -h ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20100804 ALL.2of4intersection.20100804.genotypes.vcf.gz 2:39967768-39967768
    def run_tabix(opts = {})
      (opts[:tabix_path].nil?)? (tabix = "tabix"): (tabix = "#{opts[:tabix_path]}/tabix")
      # presume you have to change directory to make it write int he correct place...still waiting to test
      tlocfile = "#{@tmp_output_dir}/chr#{@chr}.#{@from}-#{@to}.vcf"
      unless File.exists? tlocfile
        cmd = "#{tabix} #{@ct_file} #{opts[:tabix]} > #{tlocfile}"
        puts cmd
        sys = system("#{cmd}")
        raise StandardError, "tabix failed to run, please check that it is installed an available in your system path." unless sys
      else
        puts "#{tlocfile} exists, using."
      end
      @ct_file = tlocfile
    end

  end
end