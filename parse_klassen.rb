require 'rubygems'
require 'yaml'

file = "data/all_intklassen.txt"

snp_by_chr = Hash.new
File.open(file, 'r').each_with_index do |line, index|
  next if index == 0
  line = line.chomp
  #HUGO_Gene1	Chrm2	SNP_ID3	dbSNP_ID4	Type8	RefAA11	Prot_Pos13	VarAA12	SNP in Patients17	SNP in Controls18
  cols = line.split(/\t/)
  (hugo, chr, snp_id, dbSNP, type, cse, ctl) = cols.values_at(0,1,2,3,4,8,9)

  unless snp_by_chr.has_key?chr
    snp_by_chr[chr] = Array.new
  end
  snp_by_chr[chr].push([hugo, chr, snp_id, dbSNP, type, cse, ctl])
  #snp_by_chr[chr].push({:hugo => hugo, :snp_id => snp_id, :dbsnp => dbSNP, :type => type, :case => cse, :control => ctl})
end

# create random "SNP sets" from the Klassen data.  Ignore the control/case status
sets = Hash.new
# pairs, triplets, quads?
[2,3,4].each do |n|
  sets[n] = Array.new
  snp_by_chr.each_pair do |key, val|
    next if val.size < n
    puts "#{key}, #{val.size}"

    current_set = Array.new
    for i in 0..n-1
      i = rand(val.size)
      current_set.push(val[i])
    end
    sets[n].push(current_set)
  end
end

# output into useful files maybe
sets.each_pair do |key, set_list|
  set_out = File.open("sets_#{key}.txt", 'w')
  set_out.write("Set\tHugo\tchr\tsnp_id\tdbSNP\ttype\tcase\tcontrol\n")
  set_list.each_with_index do |set, j|
    set.each do |s|
      set_out.write("#{j+1}\t#{s.join("\t")}\n")
    end
  end
  set_out.close
end