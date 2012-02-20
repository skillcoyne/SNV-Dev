require 'rubygems'
require 'yaml'
require 'faraday'
require 'json'

conn = Faraday.new(:url => "http://db.systemsbiology.net") do |builder|
  builder.request :url_encoded
  builder.response :logger
  builder.adapter :net_http
end

positions = "26756102, 26756855"

response = conn.get do |req|
  req.url "/kaviar/cgi-pub/Kaviar.pl",
          req.params = {'frz' => "hg19",
                        'onebased' => "1",
                        'chr' => "chr4",
                        'pos' => positions,
                        'format' => "json"}
end

json = JSON.parse(response.body)
open("json.txt", 'w') {|f| f.write( YAML::dump(json)) }

ids = json['identifiers']

json['sites'].each do |s|
  puts "#{s['rsids'].join(',')}: #{s['position']}: #{s['variants'].keys.join(',')}\n"

  # s['variants'].each_key do |v|
  #  frequency = s['variants'][v].size
  #  puts "\t#{v}: #{frequency}\n"
  # end
end

