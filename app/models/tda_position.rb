# == Schema Information
# Schema version: 20091125220250
#
# Table name: tda_positions
#
#  id            :integer(4)      not null, primary key
#  ticker_id     :integer(4)
#  entry_price   :float
#  exit_price    :float
#  curr_price    :float
#  entry_date    :date
#  exit_date     :date
#  num_shares    :integer(4)
#  days_held     :integer(4)
#  stop_loss     :boolean(1)
#  nreturn       :float
#  rretrun       :float
#  opened_at     :datetime
#  closed_at     :datetime
#  updated_at    :datetime
#  com           :boolean(1)
#  watch_list_id :integer(4)
#

# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

class TdaPosition < ActiveRecord::Base
  belongs_to :ticker
  belongs_to  :watch_list

  include TradingCalendar

  def update_price(current_price)
    update_attribute(:curr_price, current_price)
  end

  def close(price, time)
  end

  def symbol
    ticker.symbol
  end

  def name
    symbol
  end

  def roi()
    watch_list && ((watch_list.price - entry_price)/entry_price)* 100.0
  end

  def compute_days_held
    @dh ||= trading_day_count(entry_date, Date.today, false)
    if @dh != days_held
      update_attribute(:days_held, @dh)
    end
    @dh
  end
end
