require 'vcf'

module COGIE

  ## The assumption is that these are VCF files
  class ControlSample

    attr_reader :sample

    def initialize(file)
      @ct_file = file
      parse_variations
    end

    def variations_by_location(from, to)
      vars = []
      @chr.each_value do |vcf|
        vars << vcf if (Integer(vcf.pos) >= Integer(from) and Integer(vcf.pos) <= Integer(to))
      end
      return vars
    end


    :private

    def parse_variations
      sample = File.basename(@ct_file)
      sample.sub!(/\..*/, "")
      @sample = sample
      @chr = {}

      File.open(@ct_file, 'r').each_with_index do |line, index|
        line.chomp!
        next if line.start_with?"#"
        vcf = VCF.new(line)
        #vcf.chrom
        #vcf.pos  # start location
        #vcf.qual # quality
        #vcf.samples.each_value do |s|
        #  puts s
        #end

        @chr[vcf.chrom] = [] unless @chr.has_key?vcf.chrom
        @chr[vcf.chrom] << vcf
      end
    end

  end
end