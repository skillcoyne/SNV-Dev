require 'fileutils'
require_relative 'lib/query'

# look for validated snps and possibly MAF scores?
def query_dbsnp(query, snps)

  url = "/entrez/eutils/efetch.fcgi"
  params = {'db' => 'snp',
            'id' => snps,
            'report' => 'DocSet'}

  response = query.request(url, params)
  open("data/dbsnp.txt", 'a') { |f| f.write("#{response.body}") }
end


unless ARGV.length > 0
  warn("Variant file required.")
  exit
end

FileUtils.rm_f("data/dbsnp.txt")
FileUtils.rm_f("data/no-dbsnp.txt")

file = ARGV[0]
header = nil
snps = Array.new
missed = Array.new
File.open(file, 'r') do |infile|
  index = 0
  while (line = infile.gets)
    line = line.chomp

    row = line.split(/\t/)
    if infile.lineno <= 0
      missed.push(line)
      header = row
      next
    end

    (id, chr, start_loc, end_loc, vartype, refAllele, alleleSeq, xRef) = row[0..7]
    patients = row[8, row.length]
    xRef.gsub!(/dbsnp\.\d+:/, "")
    xRef.gsub!(";", ",")

    if infile.lineno%20 == 0 or infile.eof
      query_dbsnp(Query.new("http://eutils.ncbi.nlm.nih.gov"), snps.join(","))
      snps.clear
      sleep(3)
    else
      if xRef.length > 0
        snps.push(xRef.split(","))
      else
        missed.push(line)
      end
    end

    #exit if index > 40
  end
end

open("data/no-dbsnp.txt", 'w') {|f| f.write(missed.join("\n"))}