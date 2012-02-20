require 'rubygems'
require 'yaml'
require 'net/http'
require 'json'

class EasyNet

  def EasyNet.http_post(uri, params)
    raise ArgumentError.new("uri and params expected") unless uri && params
    puts "POST #{uri} #{params}"

    begin
      response = Net::HTTP.post_form(URI.parse(uri), params)
      if Net::HTTPSuccess
        return response
      else
        puts "POST failed: #{response.code}, #{response.message}"
        puts "#{uri}, #{params}"
        return nil
      end
    rescue Exception => e
      puts "Exception " + YAML::dump(e)
      return nil
      #puts "\tPOST #{uri}\n" + YAML::dump(params)
    end

  end


  #def EasyNet.logger; RAILS_DEFAULT_LOGGER; end

  #pass in Options or URL as a string
  #options
  #   :server => "server_name" or "server_name:port"
  #   :port => 80
  #   :path
  def EasyNet.http_get(options, http_get_options={})
    if options.kind_of?(String)
      uri = URI.parse(options)
      options = { :server => uri.host, :path => uri.path, :port => uri.port }
    end
    raise ArgumentError.new(":path required (#{options.inspect})") unless options[:path] && options[:path].kind_of?(String)

    http = EasyNet.http_open(options)
    headers, data=http.get(options[:path], http_get_options)
    if (headers.code.to_i/100) != 2
      puts "HTTP server_error: #{options.inspect} #{headers.message} (#{headers.code})"
      data = nil
    end
    data
  end

  #pass in Options or URL as a string
  #options
  #   :server => "server_name" or "server_name:port"
  #   :port => 80
  def EasyNet.http_open(options)
    #puts YAML::dump(options)
    server=options.kind_of?(String) ? options : options[:server]
    server_name, port=server.split(":")
    port=options[:port] || port || 80

    raise ArgumentError.new("must specify a server") if !server

    server_name.strip!
    port=port.to_i
    Net::HTTP.new(server_name, port)
  end
end
