#--
# Copyright (c) 2008-20010 Kevin Patrick Nolan
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++
module Resourceful
  module Default
    module Actions
      # GET /tda_positions/12/edit
      def close
        load_object
        before :close
        response_for :close
      end
      # PUT /tda_positions/12
      def closed
        load_object
        before :closed
        if current_object.update_attributes object_parameters
          save_succeeded!
          after :closed
          response_for :update
        else
          save_failed!
          after :update_fails
          response_for :update_fails
        end
      end
    end
  end
end

class TdaPositionsController < ApplicationController

  extend TradingCalendar

  helper_method :watch_list_tda_positions_path

  make_resourceful do
    belongs_to :watch_list
    actions :all

    before :index do
      TdaPosition.synchronize_with_watch_list()
    end

    after :update do
      unless current_object.exit_price.blank?
        days_held = TdaPositionsController.trading_days_between(opened_at, closed_at, false)
        current_object.update_attributes!(:days_held => days_held, :exit_date => closed_at.to_date)
      end
    end

    before :create do
      current_object.entry_date = current_object.opened_at.to_date
      current_object.exit_date = nil
      current_object.closed_at = nil
      current_object.curr_price = current_object.watch_list.price || current_object.entry_price
      current_object.days_held = 0
      current_object.nreturn = 0.0
      current_object.rreturn = 0.0
      current_object.watch_list.opened_on = current_object.entry_date
      current_object.watch_list.target_rsi = nil
      current_object.watch_list.target_rvi = nil
    end

    before :close do
      tda = current_object
      tda.exit_date = Date.today
      tda.exit_price = tda.curr_price = tda.watch_list.price
      tda.days_held = TdaPositionsController.trading_day_count(tda.entry_date, tda.exit_date, false)
      tda.rreturn = tda.roi()
      tda.nreturn = (tda.days_held != 0 && tda.rreturn / tda.days_held) || tda.rreturn
    end

    after :closed do
      current_object.update_attribute(:exit_date, current_object.closed_at.to_date)
      current_object.watch_list.delete
    end

    after :update do
      current_object.update_attribute(:closed_at, nil)
    end
  end

  def new
    @tda_position = returning(TdaPosition.new) do |obj|
      obj.watch_list = parent_object
      obj.ticker_id = parent_object.ticker_id
      obj.entry_date = Date.today
      obj.entry_price = parent_object.price
      obj.num_shares = (10000.0/parent_object.price).floor if parent_object.price
      obj.curr_price = obj.entry_price
      obj.days_held = 0
      obj.nreturn = 0.0
      obj.rreturn = 0.0
    end
  end

  def watch_list_tda_positions_path(obj)
    tda_positions_path
  end
end
