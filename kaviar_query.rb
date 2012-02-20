require 'rubygems'
require 'yaml'
require 'faraday'
require 'json'

base_url = "http://db.systemsbiology.net"
conn = Faraday.new(:url => base_url) do |builder|
  builder.request :url_encoded
  builder.response :logger
  builder.adapter :net_http
end

positions = "26756102, 26756855"

#req_args = [
#    "frz=hg19",
#    "onebased=1",
#    "chr=chr4",
#    "pos=#{positions}",
#    "format=json"
#]
# response = conn.get "/kaviar/cgi-pub/Kaviar.pl?#{req_args.join('&')}"

response = conn.get do |req|
  req.url "/kaviar/cgi-pub/Kaviar.pl",
          req.params = {'frz' => "hg19",
                        'onebased' => "1",
                        'chr' => "chr4",
                        'pos' => positions,
                        'format' => "json"}
end

open("json.txt", 'w') {|f| f.write( YAML::dump(response.body)) }

json = JSON.parse(response.body)

ids = json['identifiers']
puts "#{ids.size}\n"
json['sites'].each do |s|
  puts "#{s['position']}\n"
  s['variants'].each_key do |v|
    frequency = s['variants'][v].size
    puts "\t#{v}: #{frequency}\n"
  end
end

