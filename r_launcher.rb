require 'rubygems'
require 'fileutils'
require 'yaml'
require_relative 'lib/utils'


r_file = ARGV[0]
output_file = ARGV[1]

output = `Rscript #{r_file}`

File.open(output_file, 'w') {|f| f.write(output)}
