module WatchListsHelper

  attr_reader :exit_vec

  STATUS_COLORS = {
    'W' => '#f8cdb9',
    'O' => '#f8a882',
    'C' => '#f8783d',
    'S' => '#75391d',
  }

  def price_color(watch_list)
    if session[:prices][watch_list.ticker_id].nil? or session[:prev_prices][watch_list.ticker_id].nil?
      'green'
    else
      session[:prices][watch_list.ticker_id] >= session[:prev_prices][watch_list.ticker_id] ? 'green' : 'red'
    end
  end

  def exiting_objects
    @exit_vec ||= WatchList.find(:all, :include => :tda_position,
                                 :conditions => 'opened_on IS NOT NULL', :order => 'opened_on')
    session[:prices] = exit_vec.inject({}) { |h, obj| h[obj.ticker_id] = obj.price; h}
    session[:prev_prices] = session[:prices] if session[:prev_prices].nil? or session[:prev_prices].keys != session[:prices].keys
    exit_vec
  end

  def status_color(obj)
    STATUS_COLORS[obj.status()]
  end

  def watch_lists_path
    objects_path
  end

  def watch_list_path(obj)
    object_path(obj)
  end
end
