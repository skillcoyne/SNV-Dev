# For parsing the GWASimulator control file
class GWAControl
  :female
  :male
  :female_ctrl
  :male_ctrl

  attr_accessor :filename

  def initialize(control_file)
    @filename = control_file
    @control_lines = File.open(control_file, 'r').readlines
    self.parse
  end


  # SNP window size
  def window_size
    @window
  end

  # cases as defined in control.dat
  def total_cases
    total = 0
    @cases.each {|c| total += c.to_i}
    return total
  end

  def num_cases(type)
    return @cases[0] if type == :female
    return @cases[2] if type == :female_ctrl
    return @cases[1] if type == :male
    return @cases[3] if type == :male_ctrl
  end

  # disease loci information
  def start_position(chr)
    chr = chr.sub("chr", "")
    @disease_loci[chr][0]
  end

  def end_position(chr)
    chr = chr.sub("chr", "")
    @disease_loci[chr][1]
  end

  def total_snps(chr)
    chr = chr.sub("chr", "")
    snps = @disease_loci[chr][1] - @disease_loci[chr][0]
  end

  def chromosomes
    @disease_loci.keys
  end



  def parse
    (@window, case_line, dl) = @control_lines.values_at(3, 4, 5)

    @cases = case_line.split("\s")

    @totaldl = dl.split("\s")[0]
    loci = @control_lines.slice(7, @totaldl.to_i)

    @disease_loci = Hash.new
    loci.each do |l|
      (chr, startpos, endpos) = l.split("\s").values_at(0,5,6)
      @disease_loci[chr] = [startpos.to_i, endpos.to_i]
    end

  end


end