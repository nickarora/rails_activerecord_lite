class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    @class_name.to_s.constantize #converts the string to an actual object
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    defaults = {
      :foreign_key => "#{name}_id".to_sym,
      :primary_key => :id,
      :class_name => name.to_s.camelcase
    }

    defaults.each do |key, value|
      self.send("#{key}=", options[key] || value )
    end
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    defaults = {
      :foreign_key => "#{self_class_name.to_s.underscore}_id".to_sym,
      :primary_key => :id,
      :class_name => name.to_s.singularize.camelcase
    }

    defaults.each do |key, value|
      self.send("#{key}=", options[key] || value )
    end
  end
end

module Associatable
  def belongs_to(name, options = {})
    
    self.assoc_options[name] = BelongsToOptions.new(name, options)

    assoc = self.assoc_options[name]
    define_method(name) do
      foreign_key_val = self.send(assoc.foreign_key)
      assoc.model_class.where(assoc.primary_key => foreign_key_val).first  
    end

  end

  def has_many(name, options = {})
  
    assoc = HasManyOptions.new(name, self.name, options)
    define_method(name) do
      primary_key_value = self.send(assoc.primary_key)
      assoc.model_class.where(assoc.foreign_key => primary_key_value)
    end
  end

  def assoc_options
    @assoc_options ||= {}
    @assoc_options
  end

  def has_one_through(name, through_name, source_name)
    through_options = self.assoc_options[through_name]
    source_options = through_options.model_class.assoc_options[source_name]

    define_method(name) do

      through_table = through_options.model_class.table_name
      through_fk = through_options.foreign_key # points to a column in self
      through_pk = through_options.primary_key

      source_table = source_options.model_class.table_name
      source_fk = source_options.foreign_key # points to a column in through
      source_pk = source_options.primary_key

      key = self.send(through_fk)

      results = DBConnection.execute(<<-SQL, key)
      SELECT
        #{source_table}.*
      FROM
        #{through_table}
      JOIN
        #{source_table} 
        ON #{through_table}.#{source_fk} = #{source_table}.#{source_pk}
      WHERE
        #{through_table}.#{through_pk} = ?
      SQL
      
      source_options.model_class.parse_all(results).first
    end

  end

end

