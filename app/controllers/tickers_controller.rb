class TickersController < ApplicationController

  protect_from_forgery :except => [:index, :auto_complete_for_ticker_symbol]

  auto_complete_for :ticker, :symbol

  make_resourceful do
    publish :xml, :attributes => [ :symbol, { :listing => [:name] } ]
    actions :all

  end

  def current_objects()
    @current_objects ||= current_model.paginate(:all, :page => params[:page], :per_page => 30, :include => [ :exchange, :listing] , :order => 'symbol')
  end
end
