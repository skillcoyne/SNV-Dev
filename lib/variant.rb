class Variant
  attr_accessor :id, :type, :frequency, :chromosome, :validated

  class << self;
    :validated_by;
  end

  def initialize(*args)
    @id = args[0]
    @validated = false
  end

  def validatedBy(methods)
    @validated_by = methods.split(",")
  end

  def validationMethods
    return @validated_by
  end

  def eql?(variant)
    puts "#{@id}:#{variant.id}"
    puts "#{@type}:#{variant.type}"
    puts "#{@frequency}:#{variant.frequency}"
    puts "#{@validated}:#{variant.validated}"
    puts "#{@chromosome}:#{variant.chromosome}"

    self.class.equal?(variant.class) and
        @id == variant.id and
        @type == variant.type and
        @frequency == variant.frequency and
        @validated == variant.validated and
        @chromosome == variant.chromosome
  end


end