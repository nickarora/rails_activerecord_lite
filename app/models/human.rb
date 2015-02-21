require_relative '../../lib/active_record_lite/sql_object.rb'

class Human < SQLObject
  self.table_name = 'humans'
  
  belongs_to(
    :house,
    class_name: 'House',
    foreign_key: :house_id,
    primary_key: :id)

  has_many(
    :cats,
    class_name: 'Cat',
    foreign_key: :owner_id,
    primary_key: :id)
  
  self.finalize!
end