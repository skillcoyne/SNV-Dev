require 'vcf'
require 'tmpdir'

module COGIE

  ## The assumption is that these are VCF files
  class ControlSample

    attr_reader :name, :samples, :from, :to, :pos, :ct_file

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
        #parse_variations
      else
        #parse_variations
      end
    end

    :private
    #tabix -h ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20100804 ALL.2of4intersection.20100804.genotypes.vcf.gz 2:39967768-39967768
    def run_tabix(opts = {})
      # presume you have to change directory to make it write int he correct place...still waiting to test
      tlocfile = "#{@tmp_output_dir}/chr#{@chr}.#{@from}-#{@to}.vcf"
      unless File.exists? tlocfile
        cmd = "tabix #{@ct_file} #{opts[:tabix]} > #{tlocfile}"
        puts cmd
        sys = system("#{cmd}")
        raise StandardError, "tabix failed to run, please check that it is installed an available in your system path." unless sys
      else
        puts "#{tlocfile} exists, using."
      end
      @ct_file = tlocfile
    end

    def parse_variations
      sample = File.basename(@ct_file)
      sample.sub!(/\..*/, "")
      @name = sample
      @samples = []
      @pos = {}

      File.open(@ct_file, 'r').each_with_index do |line, index|
        line.chomp!
        last_samp = nil
        next if line.start_with? "#"
        vcf = Vcf.new(line)
        last_samp = vcf.samples.length if last_samp.nil?
        @samples = vcf.samples.keys if @samples.empty?
        #@sample = Hash[ vcf.samples.keys.map {|s| [s,{}] } ] if @sample.empty?
        #
        #vcf.samples.each_key do |s|
        #  @sample[s][vcf.pos] = vcf.samples[s]['GT']
        #  #puts "#{s} #{vcf.samples[s]['GT']}" # genotype
        #  #puts "#{s} #{vcf.samples[s]['GL']}" # GT liklihood
        #  #puts "#{s} #{vcf.samples[s]['DS']}" # GT dosage
        #  #puts vcf.samples[s]
        #end
        puts "SAMPLE LENGTHS DON'T MATCH" unless last_samp.eql? vcf.samples.length

        @pos[vcf.pos] = [] unless @pos.has_key? vcf.pos
        @pos[vcf.pos] << vcf

      end
      @samples.uniq!
      @samples.sort!
    end

  end
end