require 'fileutils'
require 'yaml'
require_relative 'lib/variant'

def write_variant_file(file, vars)
  file.write("dbsnpID\tMAF\tFunction\tChromosome\n")
  vars.each_pair do |id, variant|
    file.write("#{variant.id}\t#{variant.frequency}\t#{variant.type}\t#{variant.chromosome}\n")
    print "#{variant.id}\t#{variant.frequency}\t#{variant.type}\t#{variant.chromosome}\n"
  end
end


unless ARGV.length > 0
  warn("DocSet snp descriptions file required.")
  exit
end


file = ARGV[0]

entries = Hash.new
not_valid = Hash.new
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
      when /^CHR=/
        var.chromosome = line.sub("CHR=", "")
    end

  end
end


write_variant_file(File.open("data/dbsnp_validated_cg_variants.txt", 'w'), entries)
write_variant_file(File.open("data/unvalidated_cg_variants.txt", 'w'), not_valid)

