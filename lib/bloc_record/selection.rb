require 'sqlite3'

module Selection
  def find(*ids)
    raise ArgumentError, 'One or more IDs is not a positive integer.' unless ids.all? {|id| id.is_a?(Integer) && id > 0}
    if ids.length == 1
      find_one(ids.first)
    else
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        WHERE id IN (#{ids.join(",")});
      SQL

      rows_to_array(rows)
    end
  end

  def find_one(id)
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE id = #{id};
    SQL

    init_object_from_row(row)
  end

  def find_by(attribute, value)
    raise ArgumentError, "Table does not include column `#{attribute}`" unless columns.include?(attribute)
    rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{attribute} = #{BlocRecord::Utility.sql_strings(value)};
    SQL

    rows_to_array(rows)
  end

  def take(num=1)
    raise ArgumentError, 'Must be a positive integer.' unless num.is_a?(Integer)
    if num > 1
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        ORDER BY random()
        LIMIT #{num};
      SQL

      rows_to_array(rows)
    else
      take_one
    end
  end

  def take_one
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY random()
      LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def first
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id ASC LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def last
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id DESC LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def all
    rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table};
    SQL

    rows_to_array(rows)
  end

  def method_missing(m, *args, &block)
    if m[0..7] == "find_by_"
      attribute = m[8..m.length-1]
      find_by(attribute, args[0])
    else
      raise NoMethodError
    end
  end

  def find_each(start=1, batch_size=nil)

    if batch_size == nil
      rows = connection.execute(<<-SQL)
        SELECT #{columns.join ","} FROM #{table}
        OFFSET start;
      SQL
    else
      rows = connection.execute(<<-SQL)
        SELECT #{columns.join ","} FROM #{table}
        LIMIT batch_size
        OFFSET start;
      SQL
    end

    rows.each do |row|
      yield init_object_from_row(row)
    end
  end

  def find_in_batches(start=1, batch_size=nil)
    if batch_size == nil
      rows = connection.execute(<<-SQL)
        SELECT #{columns.join ","} FROM #{table}
        OFFSET start;
      SQL
    else
      rows = connection.execute(<<-SQL)
        SELECT #{columns.join ","} FROM #{table}
        LIMIT batch_size
        OFFSET start;
      SQL
    end

    yield rows_to_array(rows)
  end

  private
  def init_object_from_row(row)
    if row
      data = Hash[columns.zip(row)]
      new(data)
    end
  end

  def rows_to_array(rows)
    rows.map { |row| new(Hash[columns.zip(row)]) }
  end
end
