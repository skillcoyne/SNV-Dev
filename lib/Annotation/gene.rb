require_relative 'bio_entity'

class Gene < BioEntity
  attr_accessor :chr, :start, :end

  def initialize(opts = {})
    raise ArgumentError, "Gene :id and :id_type required. :chr, :start and :end optional." unless opts[:id] and opts [:type]
    super(opts[:id], opts[:type])

    opts[:chr]? (@chr = opts[:chr]): (@chr = nil)
    opts[:start]? (@start = opts[:start]): (@start = nil)
    opts[:end]? (@end = opts[:end]): (@end = nil)
  end

end