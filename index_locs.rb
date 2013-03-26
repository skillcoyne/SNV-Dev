require 'fileutils'

dir = "/work/projects/cogie/patients"
i = 0
locations = {}

files = Dir["#{dir}/**/*.txt"]

files.each do |file|
  puts file
  File.open(file, 'r').each_line do |line|
    line.chomp!
    cols = line.split("\t")
    chr = cols[0]
    locs = cols[1..cols.length]
	
    (locations[chr] ||=[]) << locs
   end
    i+=1
end
locations.each_pair{|k,v| v.flatten!; v.uniq!; v.sort! }

loc_file = "#{dir}/chr_locations.txt"
# Chromosome locations file
locations = Hash[locations.sort]
File.open(loc_file, 'w') do |fout|
  fout.write "# Each line is formatted as: <chr> <list of locations from patient files>\n"
  locations.each_pair do |chr, locs|
    fout.write "#{chr}\t" + locs.join("\t") + "\n"
  end
end

