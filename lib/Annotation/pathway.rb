require_relative 'bio_entity'

class Pathway < BioEntity
  attr_accessor :name, :database, :entities

  def initialize(opts = {})
    raise ArgumentError "Pathway :id and :type required. :name, :database and :entities list optional." unless opts[:id] and opts[:database]
    super(opts[:id], opts[:type])

    opts[:name]? (@name = opts[:name]): (@name = nil)
    opts[:database]? (@database = opts[:database]): (@database = nil)
    opts[:entities]? (@entities = opts[:entities]): (@entities = Array.new)
  end

end