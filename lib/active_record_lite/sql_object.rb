require_relative '../../db/db_connection'
require_relative 'attr_accessor_object'
require_relative 'searchable'
require_relative 'associatable'
require 'active_support/inflector'

class SQLObject

  extend Searchable
  extend Associatable

  def self.columns
    return @columns unless @columns.nil?

    query = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        "#{self.table_name}"
    SQL

    @columns = query.first.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |name|
      define_method("#{name}") do
        self.attributes[name]
      end

      define_method("#{name}=") do |val|
        self.attributes[name] = val
      end

    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
      #{self.table_name}.*
      FROM
      #{self.table_name}
    SQL

    parse_all(results)
  end

  def self.parse_all(results)
    obj_arr = []

    results.each do |result|
      obj_arr << self.new(result)
    end
    
    obj_arr
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL)
      SELECT
      #{self.table_name}.*
      FROM
      #{self.table_name}
      WHERE
      id = #{id}
    SQL

    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      raise "unknown attribute \'#{attr_name}\'" unless self.class.columns.include?(attr_name)
      self.send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |a| attributes[a] }
  end

  def insert
    col_names = self.class.columns.join(",")
    question_marks = (["?"] * self.class.columns.count).join(",")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL
    
    self.id = DBConnection.last_insert_row_id
  end

  def update
    cols = self.class.columns.join(" = ?, ") + " = ?"
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{ cols }
      WHERE
        id = ?
    SQL
  end

  def save
    self.id.nil? ? self.insert : self.update
  end

end
