require 'railslite/railslite_controllerbase'

describe RailsLite::ControllerBase do
  before(:all) do
    class Owner
      attr_reader :fname, :lname

      def initialize
        @fname = 'Bob'
        @lname = 'Barker'
      end
    end

    class Cat
      attr_reader :name, :owner

      def initialize
        @name = 'GIZMO'
        @owner = Owner.new
      end
    end

    class CatsController < RailsLite::ControllerBase
      def index
        @cats = [Cat.new]
      end
    end
  end
  after(:all) { Object.send(:remove_const, "CatsController") }

  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }
  let(:cats_controller) { CatsController.new(req, res) }

  describe "#render" do
    before(:each) do
      cats_controller.render(:index)
    end

    it "renders the html of the index view" do
      cats_controller.res.body.should include("ALL THE CATS")
      cats_controller.res.body.should include("<h1>")
      cats_controller.res.content_type.should == "text/html"
    end

    describe "#already_built_response?" do
      let(:cats_controller2) { CatsController.new(req, res) }

      it "is false before rendering" do
        cats_controller2.already_built_response?.should be false
      end

      it "is true after rendering content" do
        cats_controller2.render(:index)
        cats_controller2.already_built_response?.should be true
      end

      it "raises an error when attempting to render twice" do
        cats_controller2.render(:index)
        expect do
          cats_controller2.render(:index)
        end.to raise_error
      end

      it "captures instance variables from the controller" do
        cats_controller2.index
        cats_controller2.render(:index)
        expect(cats_controller2.res.body).to include("GIZMO")
      end
    end
  end
end
