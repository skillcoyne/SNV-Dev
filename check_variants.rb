require 'fileutils'
require 'yaml'
require_relative 'lib/variant'

def write_variant_file(file, vars)
  file.write("dbsnpID\tChromosome\tClassification\tFunction\tMAF\n")
  vars.each_pair do |id, variant|
    str = "#{variant.id}\t#{variant.chromosome}\t#{variant.classification}\t#{variant.type}\t#{variant.frequency}\n"
    file.write(str)
    print str
  end
end


unless ARGV.length > 0
  warn("DocSet snp descriptions file required.")
  exit
end


file = ARGV[0]

entries = Hash.new
not_valid = Hash.new
variant_types = Hash.new
var = Variant.new

File.open(file, 'r') do |infile|
  while (line = infile.gets)
    line = line.chomp

    # special case first id
    if line.match(/rs\d+/) and infile.lineno <= 1
      id = line.match(/rs\d+/)
      var = Variant.new(id)
    end

    if (line.match(/rs\d+/) or infile.eof) and infile.lineno > 1
      if entries.has_key? id
        unless var.eql?(entries[id])
          puts "#{id} needs to be looked at"
        end
      end
      if var.validated #and maf
        entries[id] = var
      else
        not_valid[id] = var
      end
      id = nil
      line =~ /rs\d+ has merged into (rs\d+)/ ? id = $1 : id = line.match(/rs\d+/)
      var = Variant.new(id)
    end

    case line
      when /^GLOBAL_MAF/
        var.frequency = line.sub("GLOBAL_MAF=", "")
      when /^VALIDATED/
        var.validated = true unless line =~ /no-info/
      when /^FXN_CLASS/
        var.type = line.sub("FXN_CLASS=", "")
        var.type.split(",").each do |t|
          t = "N/A" if t.eql?("")
          (variant_types.key? t) ? (variant_types[t] = variant_types[t] + 1) : (variant_types[t] = 1)
        end
      when /^CHR=/
        var.chromosome = line.sub("CHR=", "")
      when /^SNP_CLASS/
        var.classification = line.sub("SNP_CLASS=", "")
    end
  end
end


write_variant_file(File.open("data/dbsnp_validated_cg_variants.txt", 'w'), entries)
write_variant_file(File.open("data/unvalidated_cg_variants.txt", 'w'), not_valid)

File.open("data/variant_types.txt", 'w') { |f|
  variant_types.each_pair do |type, total|
    f.write("#{type}\t#{total}\n")
  end
}