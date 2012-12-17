



file = "/Users/sarah.killcoyne/Data/cogie-tmp/AID1207_SID5717_ROL_0621.B68.func"

fout = File.open("/Users/sarah.killcoyne/Data/cogie-tmp/AID1207-sample.txt", 'w')

File.open(file, 'r').each_with_index do |line, index|
  fout.write(line)

  puts index
  line.chomp!

  puts line if line.start_with?"###"

  cols = line.split("\t")

  puts line if cols.length > 2

  break if index > 10

end