require 'rubygems'
require 'fileutils'
require 'yaml'
require_relative 'lib/utils'

summary = ARGV[0]

summary = "data/summary_example.txt"

#Level    Best Models                  Classification Accuracy
#"1"   "chr12_SNP49"                "56.48"
#* "2"   "chr12_SNP5"   "chr12_SNP48" "60.96"
#Prediction Accuracy    Cross-Validation Consistency
#"52.04"                "2"
#* "57.09"                "2"
#'*' indicates overall best model

models = 0; prediction = 0
model_def = Hash.new
File.open(summary, 'r').each_line do |line|
  line = line.chomp.lstrip
  cols = line.split(/\s{2,}/)
  models = 1 if cols[0].eql?("Level")
  prediction = 0 if cols[0].eql?("Prediction Accuracy")
  if cols[0] =~ /^'*'/
    models = 0
    prediction = 0
  end

  puts(cols.join(', '))

  if models

  end



end
