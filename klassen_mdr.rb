require 'yaml'
require 'set'

max = 300
a = (1..400).to_a.sample max
random = Hash[a.map {|x| [x, nil]}]


classStats = {"case" => Array.new, "control" => Array.new}
cases = Hash.new
controls = Hash.new
allSNPs = Array.new
File.open("data/cases_controls.txt", 'r').each_line do |line|
  line = line.chomp

  (chr, snp, is_case, is_ctrl, type) = line.split("\t")
  if type =~ /missense_mutation/
    allSNPs.push(snp)

    if is_case.eql?"yes"
      classStats["case"].push(snp)
      cases[snp] = type
    end

    if is_ctrl.eql?"yes"
      classStats["control"].push(snp)
      controls[snp] = type
    end
  end
end

#File.open("data/all_intklassen.txt", 'r').each_with_index do |line, index|
#  line = line.chomp
#  next if index <= 0
#  (hugo, chr, snpID, dbSNP, type, aa1, protPos, aa2, patient, control) = line.split("\t")
#  if type =~ /missense_mutation/
#    classStats["case"].push(snpID) if patient.eql?"yes"
#    classStats["control"].push(snpID) if patient.eql?"no"
#  end
#end

totalCases =  Float(classStats["case"].length)
totalControls =  Float(classStats["control"].length)
total = totalControls + totalCases

puts "Controls: #{totalControls}, #{totalControls/total*100}"
puts "Cases: #{totalCases}, #{totalCases/total*100}"

#File.open("data/klassen_mdr.txt", 'w') {|f|}

snp_list = []
case_list = Array.new(max)
ctrl_list = Array.new(max)
random.each_key do |r|
#  snp_list.push( allSNPs[r] )

  allSNPs[r]

  case_list[r][allSNPs[r]] = cases[allSNPs[r]]



end

