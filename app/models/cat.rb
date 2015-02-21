require_relative '../../lib/active_record_lite/sql_object.rb'

class Cat < SQLObject
  
  belongs_to(
    :owner,
    {
    class_name: :Human,
    foreign_key: :owner_id,
    primary_key: :id 
    })
  
  
  self.finalize!
end