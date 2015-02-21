require 'active_support'
require 'active_support/core_ext'
require 'erb'
require 'uri'
require 'json'
require 'webrick'

module RailsLite
	
	class ControllerBase

		attr_reader :req, :res, :params

		# setup the controller
    def initialize(req, res, route_params = {})
    	@req = req
      @res = res
      @already_built_response = false
    	@params = Params.new(req, route_params)

      # protect_from_forgery with: :exception
    	session[:form_authenticity_token] ||= SecureRandom.urlsafe_base64

    	if [:post, :patch, :put].include?(format_req(@req.request_method)) && 
    		 @params[:authenticity_token] != session[:form_authenticity_token]
				raise "Unauthorized Action"
			end
    end

    # Helper method to alias @already_built_response
    def already_built_response?
      @already_built_response
    end

    # Set the response status code and header
    def redirect_to(url)
      raise "Can not re-render content." if self.already_built_response?
      @already_built_response = true
      res.status = 302
      res.header['location'] = url
      flash.store_flash(@res)
      session.store_session(@res)
    end

    # Populate the response with content.
    # Set the response's content type to the given type.
    # Raise an error if the developer tries to double render.
    def render_content(content, type)
      raise "Can not re-render content." if self.already_built_response?
      @already_built_response = true
      res.body = content
      res.content_type = type
      flash.store_flash(@res)
      session.store_session(@res)
    end

    # use ERB and binding to evaluate templates
    # pass the rendered html to render_content
    def render(template_name)
      folder_name = self.class.to_s.underscore[0..-12]
      template = File.read("app/views/layouts/application.html.erb")
    	filename = "app/views/#{folder_name}/#{template_name}.html.erb"
    	template += File.read(filename)
    	content = ERB.new(template).result(binding) #add instance variables
    	render_content(content, "text/html")
    end

    # method exposing a `Session` object
    def session
    	@session ||= Session.new(self.req)
    end    

    def form_authenticity_token
    	session[:form_authenticity_token]
    end

    def format_req(r)
      r.to_s.downcase.to_sym
    end

    # use this with the router to call action_name (:index, :show, :create...)
    def invoke_action(name)
    	self.send(name)
    	render(name) unless already_built_response?  #default response!
    end

	  # method exposing a `Flash` object
	  def flash
	  	@flash ||= Flash.new(self.req)
	  end

		def link_to(name, url = '#')
			"<a href=#{url}>#{name}</a>"
		end

		def button_to(name, url = '#', method)
			"<form action=#{url} method='#{method.to_s.upcase}'><input type='submit' value='#{name}'></form>"
		end

	end

	class Route
    attr_reader :pattern, :http_method, :controller_class, :action_name

    def initialize(pattern, http_method, controller_class, action_name)
      @pattern = pattern
      @http_method = http_method
      @controller_class = controller_class
      @action_name = action_name
    end

    # checks if pattern matches path and method matches request method
    def matches?(req)
      return false unless (http_method == req.request_method.downcase.to_sym) && @pattern.match(req.path) 
      true
    end

    # use pattern to pull out route params (save for later?)
    # instantiate controller and call controller action
    def run(req, res)
      data = @pattern.match(req.path)

      route_params = {}
      data.names.each do |name| #names => :id, etc.
          route_params[name] = data[name]
      end

      @controller_class.new(req, res, route_params).invoke_action(@action_name)
    end
	end

	class Router
    attr_reader :routes

    def initialize
        @routes = []
    end

    # simply adds a new route to the list of routes
    def add_route(pattern, method, controller_class, action_name)
        @routes << Route.new(pattern,method,controller_class, action_name)
    end

    # evaluate the proc in the context of the instance
    # for syntactic sugar :)
    def draw(&proc)
        instance_eval(&proc)
    end

    # make each of these methods that
    # when called add route
    [:get, :post, :put, :delete].each do |http_method|
        define_method(http_method) do |pattern, controller_class, action_name|
            add_route(pattern, http_method, controller_class, action_name)
        end
    end

    # should return the route that matches this request
    def match(req)
        routes.find { |r| r.matches?(req) }
    end

    # either throw 404 or call run on a matched route
    def run(req, res)
        correct_route = match(req)

        if correct_route.nil?
            res.status = 404
        else
            correct_route.run(req,res)
        end
    end

	end

  class Flash
  	
		def initialize(req)
			@req = req

			cookie = @req.cookies.find {|c| (c.name == '_flash_rails_lite_app') }
			
			if cookie
				@current_data = JSON.parse(cookie.value)
			else
				@current_data = {}
			end

			@future_data = {}
		end

		def [](key)
			@current_data[key.to_s]
		end

		def []=(key, val)
			@future_data[key] = val
		end

		def store_flash(res)
			c = WEBrick::Cookie.new('_flash_rails_lite_app', @future_data.to_json) 
			c.path = "/"
    	res.cookies << c
    end

  end

  class Params
    
    def initialize(req, route_params = {})
      @params = Hash.new(nil)

      @params.merge!(route_params)
      
      if req.query_string
          @params.merge!(parse_www_encoded_form(req.query_string))
      end

      if req.body
          @params.merge!(parse_www_encoded_form(req.body))
      end
    end

    def [](key)
      @params[key.to_s]
    end

    def to_s
      @params.to_json.to_s
    end

    def require(key)
      self[key] || fail
    end

    class AttributeNotFoundError < ArgumentError; end;

    private
    # this should return deeply nested hash
    # argument format
    # user[address][street]=main&user[address][zip]=89436
    # should return
    # { "user" => { "address" => { "street" => "main", "zip" => "89436" } } }
    def parse_www_encoded_form(www_encoded_form)
      array = URI::decode_www_form(www_encoded_form)
      params = {}

      array.each do |key,val|
        subkeys = parse_key(key)
        if subkeys.count > 1
          hash = params
          until subkeys.empty?
            newkey = subkeys.shift
            unless subkeys.empty?
              hash[newkey] ||= {}
              hash = hash[newkey]
            else
              hash[newkey] = val
            end
          end
        else
          params[key] = val      
        end
      end
      
      params
    end

    # this should return an array
    # user[address][street] should return ['user', 'address', 'street']
    def parse_key(key)
      key.split(/\]\[|\[|\]/)
    end

  end

  class Session
    # find the cookie for this app
    # deserialize the cookie into a hash
    def initialize(req)
      @req = req
      cookie = @req.cookies.find {|c| c.name == '_rails_lite_app'}
      if cookie
          @data = JSON.parse(cookie.value)
      else
          @data = {}
      end
    end

    def [](key)
      @data[key.to_s]
    end

    def []=(key, val)
      @data[key.to_s] = val
    end

    # serialize the hash into json and save in a cookie
    # add to the responses cookies
    def store_session(res)     
      c = WEBrick::Cookie.new('_rails_lite_app', @data.to_json)
      c.path = "/"
      res.cookies << c
    end

  end

end

class Hash
  def permit(*keys)
    output = {}
    keys.each do |key|
      output[key] = self[key.to_s]
    end

    output
  end
end