require 'sqlite3'
require 'pg'

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

  def where(*args)
    if args.count > 1
      expression = args.shift
      params = args
    else
      case args.first
      when String
        expression = args.first
      when Hash
        expression_hash = BlocRecord::Utility.convert_keys(args.first)
        expression = expression_hash.map {|key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}"}.join(" and ")
      end
    end

    sql = <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{expression};
    SQL

    rows = connection.execute(sql, params)
    rows_to_array(rows)
  end

  def order(*args)
    arr = []
    args.each do |arg|
      case arg
      when String
        arr << arg
      when Symbol
        arr << arg.to_s
      when Hash
        arr << arg.map{|key, value| "#{key} #{value}"}
      end
    end
    order = arr.join(",")
    rows = connection.execute <<-SQL
      SELECT * FROM #{table}
      ORDER BY #{order};
    SQL
    rows_to_array(rows)
  end

  def join(*args)
    if args.count > 1
      joins = args.map { |arg| "INNER JOIN #{arg} ON #{arg}.#{table}_id = #{table}.id"}.join(" ")
      rows = connection.execute <<-SQL
        SELECT * FROM #{table} #{joins}
      SQL
    else
      case args.first
      when String
        rows = connection.execute <<-SQL
          SELECT * FROM #{table} #{BlocRecord::Utility.sql_strings(args.first)};
        SQL
      when Symbol
        rows = connection.execute <<-SQL
          SELECT * FROM #{table}
          INNER JOIN #{args.first} ON #{args.first}.#{table}_id = #{table}.id
        SQL
      when Hash
        key = args.first.keys.first
        value = args.first[key]
        rows = connection.execute <<-SQL
          SELECT * FROM #{table}
          INNER JOIN #{key} ON #{key}.#{table}_id = #{table}.id
          INNER JOIN #{value} ON #{value}.#{key}_id = #{key}.id
        SQL
      end
    end

    rows_to_array(rows)
  end

  private
  def init_object_from_row(row)
    if row
      data = Hash[columns.zip(row)]
      new(data)
    end
  end

  def rows_to_array(rows)
    collection = BlocRecord::Collection.new
    rows.each { |row| collection << new(Hash[columns.zip(row)]) }
    collection
  end
end
