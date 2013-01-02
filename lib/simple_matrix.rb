require 'yaml'
require 'matrix'

class SimpleMatrix

  attr_reader :colnames, :rownames

  def initialize()
    @colnames = []
    @rownames = []
    @rows = []
    @cols = []
  end

  # Set all column names.
  def colnames=(names)
    @colnames = names
    names.each_with_index { |e, i| @cols[i] = [] } if @cols.length <= 0
  end

  # Set all rownames
  def rownames=(names)
    @rownames = names.map { |e| e.to_s }
    names.each_with_index { |e, i| @rows[i] = [] } if @rows.length <= 0
  end

 # Returns all columns.
  def columns
    @cols
  end

  # Returns all rows.
  def rows
    @rows
  end

  # Retrieve column by name.  If multiple columns have the same name only the first one will be returned.
  def column(name)
    index = @colnames.index(name.to_s)
    @cols[index]
  end

  # Retrieve row by name.  If multiple rows have the same name only the first one will be returned.
  def row(name)
    index = @rownames.index(name.to_s)
    @rows[index]
  end

  # Add row to the matrix.
  # Parameter:
  #  - name:  Row name, does not need to be unique.  However if it is not then retrieving elements by named row
  #           will not be predictable.
  #  - row: Array of values of the same length as the current rows.
  def add_row(name, row)
    raise ArgumentError, "Row was #{row.length}, expected #{@colnames.length} elements." unless row.length.eql? @colnames.length
    raise ArgumentError, "Duplicate row names not allowed: #{name}" if @rownames.index(name)

    @rows << row.to_a
    row.each_with_index do |r, i|
      @cols[i] << r
    end
    @rownames << name.to_s
  end

  # Add column to the matrix.
  # Parameter:
  #  - name:  Column name, must be unique.
  #  - col: Array of values of the same length as the current columns.
  def add_column(name, col)
    raise ArgumentError, "Column was #{col.length}, expected #{@rownames.length} elements." unless col.length.eql? @rownames.length
    raise ArgumentError, "Duplicate column names not allowed: #{name}" if @colnames.index(name)

    @cols << col.to_a
    col.each_with_index do |c, i|
      @rows[i] << c
    end
    @colnames << name.to_s
  end

  # Add element to the matrix.
  # Parameters:
  #   - row: Row name or index.
  #   - col: Column name or index.
  #   - e: Element to be added at the coordinates specified.
  def add_element(row, col, e)
    if (row.is_a? String or col.is_a? String)
      i = @rownames.index(row.to_s)
      raise ArgumentError, "Row '#{row}' does not exist." if i.nil?
      j = @colnames.index(col.to_s)
      raise ArgumentError, "Column '#{col}' does not exist." if j.nil?
    else
      i = row; j = col
      raise ArgumentError, "Row(#{i}) or Col(#{j}) is out of bounds" unless (@rows[i] and @cols[j])
    end
    @rows[i][j] = e
    @cols[j][i] = e
  end

  # WARNING THIS CHANGES ALL VALUES FOR A GIVEN COLUMN
  def update_column(col, values)
    raise ArgumentError, "Expect #{@rownames.length} values for the #{col} column." unless values.length.eql?@rownames.length

    i = col
    if col.is_a?String
      i = @colnames.index(col)
    end
    raise ArgumentError, "No column found for #{col}" if i.nil? or @cols[i].nil?

    @cols[i] = values
    values.each_with_index do |e, j|
      @rows[j][i] = e
    end
  end

  # Returns element at given location.  Row/column names can be provided,
  # but if one is a name both are treated as such.  Otherwise they are expected
  # to be indicies.
  def element(row, col)
    if (row.is_a? String or col.is_a? String)
      i = @rownames.index(row.to_s)
      j = @colnames.index(col.to_s)
    else
      i = row; j = col
    end
    return @rows[i][j]
  end

  # Return array [total rows, total columns]
  def size
    return [@rows.length, @cols.length]
  end

  # Returns matrix as a string.
  # Opts:
  #  :rownames => true  (default)  Output row names.
  #  :colnames => true  (default)  Output column names.
  def to_s(rownames = true, colnames = true)
    matrix_string = ""
    matrix_string = "\t" unless rownames.eql? false
    matrix_string += @colnames.join("\t") + "\n" unless colnames.eql? false # unless (opts[:colnames] and opts[:colnames].eql?false)
    rowname = ""
    @rows.each_with_index do |row, i|
      rowname = "#{@rownames[i]}\t" unless rownames.eql? false # opts[:rownames].eql?false
      row = row.to_a
      matrix_string += rowname + row.join("\t") + "\n"
    end
    return matrix_string
  end

  # Write the matrix to a file or to STDOUT
  # Opts:
  #  :rownames => true  (default)  Output row names.
  #  :colnames => true  (default)  Output column names.
  def write(file = nil, opts = {})
    matrix_string = self.to_s(opts[:rownames], opts[:colnames])
    if file
      File.open(file, 'w') { |fout| fout.write(matrix_string) }
      puts "#{file} written."
    else
      puts matrix_string
    end
  end

  # Get the Ruby Matrix object that is usable for matrix mathematical operations.
  def to_matrix
    puts "Rows of #{self.name} are not integers. Matrix math operations may not work." if (rows.select { |e| !e.is_a? Integer }.empty?)
    return Matrix.rows(self.rows)
  end

end