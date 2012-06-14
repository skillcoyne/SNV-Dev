require 'yaml'

#sets=ARGV[0]
#dir=ARGV[1]

sets=5
dir="C:/Users/LCSB_Student/workspace/SNV-Dev/data"

script="C:/Users/LCSB_Student/workspace/SNV-Dev/klassen.R"

sets.times {|n|
  output=`Rscript #{script} #{dir} #{n}`
  puts(output)
}




