require_relative '../lib/railslite/railslite_controllerbase.rb'
require_relative '../config/routes.rb'
require_relative '../db/db_connection'
require_relative '../app/requires.rb'

router = RailsLite::Router.new
router.draw(&Routes::routes);

# The Server
# Comparable to running "rails s" from the command line
server = WEBrick::HTTPServer.new(Port: 3000)
server.mount_proc('/') do |req, res|
  route = router.run(req, res)
end
trap('INT') { server.shutdown }
server.start