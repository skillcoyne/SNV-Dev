require 'yaml'
require 'faraday'

class Query

  class << self;
    attr_accessor :baseURL, :requestURL, :conn
  end

  #default
  def initialize(baseURL)
    @baseURL = baseURL

    @conn = Faraday.new(:url => @baseURL) do |builder|
      builder.request :url_encoded
      builder.response :logger
      builder.adapter :net_http
    end
  end


  def request(requestURL, params = {})
    return response = @conn.get do |req|
      req.url requestURL,
            req.params = params
    end
  end



end