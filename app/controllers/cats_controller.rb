# Controller
# Designed to work in a manner similar to Ruby on Rails
class CatsController < RailsLite::ControllerBase

  def index
    @cats = Cat.all
    render :index
  end

  def new
    @cat = Cat.new
    @owners = Human.all
    render :new
  end

  def create
    @cat = Cat.new(cat_params)

    if @cat.save
      flash[:errors] = ["CAT CREATED"]
      redirect_to '/'  
    else
      render :new
    end
  end

  private

  def cat_params
    params.require(:cat).permit(:name, :owner_id)
  end

end