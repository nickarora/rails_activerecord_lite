# Router
# Designed to work in a manner similar to 
# Ruby on Rails' 'config/routes.rb'
module Routes
	def self.routes
		Proc.new {
		  post Regexp.new("^/cats$"), CatsController, :create
		  get Regexp.new("^/$"), CatsController, :index
		  get Regexp.new("^/cats$"), CatsController, :index
		  get Regexp.new("^/cats/new$"), CatsController, :new
	  }
	end
end