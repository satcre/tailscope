class GoodController < ApplicationController
  before_action :authenticate_user!

  def index
    @items = Item.all
  end

  private

  def item_params
    params.require(:item).permit(:name, :description)
  end
end
