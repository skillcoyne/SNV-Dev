require 'yaml'

record = 0
i = 0
File.open("data/dbsnp_all.txt", 'r').each_line do |line|


  record = 1 if line =~ /(\d+) Homo sapiens/

  record = 0 if line =~ /^\s+$/

  puts line
  puts record

  i = i + 1
  break if i > 30
end
