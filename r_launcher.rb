require 'rubygems'
require 'fileutils'
require 'yaml'
require_relative 'lib/utils'


r_file = ARGV[0]

output = `Rscript #{r_file}`