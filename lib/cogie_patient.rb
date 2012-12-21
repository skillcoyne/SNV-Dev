require 'yaml'
require_relative 'func'

module COGIE

  class COGIEPatient

    attr_reader :genes, :chrs, :patient, :locs, :variations

    def initialize(file)
      @pt_file = file
      @patient = File.basename(file).sub!(/\..*$/, "")

      Func.check_format(file)
      parse_variations
    end

    # Options: :variations, :genes
    def sum(opts = {})
      count = 0
      if opts[:variations]
        @genes.each_pair { |g, c| count += c.length }
      elsif opts[:genes]
        count = @genes.keys.length
      end
      return count
    end

    def sort_by_location
      @variations.sort_by! {|v| v.from }
    end

    def sort_by_chr
      @variations.sort_by! {|v| v.chrom }
    end

    def sort_by_type
      @variations.sort_by! {|v| v.type }
    end

    def variations_by_location(from, to)
      vars = []
      puts @genes
      @genes.each_pair do |g, list|
        list.each do |v|
          vars << v if (v.start_loc >= from and v.end_loc <= to)
        end
      end
      return vars
    end

    :private

    def parse_variations
      @chrs = {}; @genes = {}; @locs = []; @variations = []
      puts "Parsing #{@pt_file}..."
      File.open(@pt_file, 'r').each_with_index do |line, index|
        next unless index > 2
        next if line.start_with? "#" # the header lines are repeated throughout the file
        line.chomp!
        cgf = Func.new(line)
        @chrs[cgf.chr] = [] unless @chrs.has_key? cgf.chr
        @chrs[cgf.chr] << cgf

        @genes[cgf.gene] = [] unless @genes.has_key? cgf.gene
        @genes[cgf.gene] << cgf
        @locs << cgf.from
        @variations << cgf
        break if index > 20
      end
      @genes.each_pair { |k, v| v.sort_by! { |cgf| cgf.from } }
      @chrs.each_pair { |k, v| v.sort_by! { |cgf| cgf.from } }
      @locs.sort!
      @locs.uniq!
      puts "#{@pt_file} read."
    end

  end


end