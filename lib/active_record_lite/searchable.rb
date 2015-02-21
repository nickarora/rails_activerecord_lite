module Searchable
  def where(params)

  	where_line = params.map {|k,v| "#{k} = ?"}.join("AND ")

    results = DBConnection.execute(<<-SQL, params.values)
    	SELECT
    		*
    	FROM
    		#{self.table_name}
    	WHERE
    		#{ where_line }
    SQL

    parse_all(results)
  end
end