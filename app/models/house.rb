require_relative '../../lib/active_record_lite/sql_object.rb'

class House < SQLObject
	has_many(
	  :humans,
	  class_name: 'Human',
	  foreign_key: :house_id,
	  primary_key: :id)
	

  self.finalize!
end