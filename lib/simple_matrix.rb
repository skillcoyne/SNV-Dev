require 'yaml'

class SimpleMatrix

  attr_reader :colnames, :rownames

  def initialize(default = 0)
    @colnames = []
    @rownames = []
    @rows = []
    @cols = []
    @def_value = default
  end

  def colnames=(names)
    @colnames = names
    names.each_with_index { |e, i| @cols[i] = [] } if @cols.length <= 0
  end

  def rownames=(names)
    @rownames = names.map { |e| e.to_s }
    names.each_with_index { |e, i| @rows[i] = [] } if @rows.length <= 0
  end

  def columns
    @cols
  end

  def rows
    @rows
  end

  def column(name)
    index = @colnames.index(name.to_s)
    @cols[index]
  end

  def row(name)
    index = @rownames.index(name.to_s)
    @rows[index]
  end

  def add_row(name, row)
    raise ArgumentError, "Row was #{row.length}, expected #{@colnames.length} elements." unless row.length.eql? @colnames.length
    @rows << row.to_a
    row.each_with_index do |r, i|
      @cols[i] << r
    end
    @rownames << name
  end

  def add_column(name, col)
    raise ArgumentError, "Column was #{col.length}, expected #{@rownames.length} elements." unless col.length.eql? @rownames.length
    @cols << col.to_a
    col.each_with_index do |c, i|
      @rows[i] << c
    end
    @colnames << name
  end

  def element(row, col)
    if (row.is_a? String or col.is_a? String)
      i = @rownames.index(row.to_s)
      j = @colnames.index(col.to_s)
    else
      i = row; j = col
    end
    return @rows[i][j]
  end

  def size
    return [@rows.length, @cols.length]
  end

  def to_s(rownames = true, colnames = true)
    matrix_string = ""
    matrix_string = "\t" unless rownames.eql?false
    matrix_string += @colnames.join("\t") + "\n" unless colnames.eql?false # unless (opts[:colnames] and opts[:colnames].eql?false)
    rowname = ""
    @rows.each_with_index do |row, i|
      rowname = "#{@rownames[i]}\t" unless rownames.eql?false # opts[:rownames].eql?false
      row = row.to_a
      matrix_string += rowname + row.join("\t") + "\n"
    end
    return matrix_string
  end

  def write(file = nil, opts = {})
    matrix_string = self.to_s(opts[:rownames], opts[:colnames])
    if file
      File.open(file, 'w') { |fout| fout.write(matrix_string) }
      puts "#{file} written."
    else
      puts matrix_string
    end
  end



end