# == Schema Information
# Schema version: 20091125220250
#
# Table name: sim_positions
#
#  id               :integer(4)      not null, primary key
#  entry_date       :datetime
#  exit_date        :datetime
#  quantity         :integer(4)
#  entry_price      :float
#  exit_price       :float
#  nreturn          :float
#  roi              :float
#  days_held        :integer(4)
#  eorder_id        :integer(4)
#  xorder_id        :integer(4)
#  ticker_id        :integer(4)
#  static_exit_date :date
#  position_id      :integer(4)
#

# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

require 'ostruct'

class SimPosition < ActiveRecord::Base
  belongs_to :eorder, :class_name => 'Order'
  belongs_to :xorder, :class_name => 'Order'
  belongs_to :ticker
  belongs_to :position, :class_name => 'TempPositionTemplate'

  @@open_position_count = 0

  def after_create
    eorder.update_attribute(:sim_position_id, self.id)
  end

  extend TradingCalendar

  def volume()
    day_before = SimPosition.trading_date_from(entry_date, -1)
    (bar = DailyBar.find_by_ticker_and_date(ticker_id, day_before.to_date)) && bar.volume
  end

  class << self

    def open_position_count
      @@open_position_count
    end

    def exiting_positions(date)
      find(:all, :conditions => { :static_exit_date => date } )
    end

    def open_positions()
      find(:all, :conditions => { :exit_date => nil })
    end

    def open(order, options={})
      @@open_position_count += 1
      attrs = OpenStruct.new()
      attrs.eorder_id = order.id
      attrs.entry_date = order.filled_at
      attrs.quantity = order.quantity
      attrs.entry_price = order.fill_price
      attrs.ticker_id = order.ticker_id
      attrs.static_exit_date = options[:exit_date]
      attrs.position_id = options[:position_id]
      pos = create! attrs.marshal_dump
    end

    def truncate()
      connection.execute("truncate #{table_name}")
    end
  end

  def event_time()
    exit_date || entry_date
  end

  def symbol
    ticker.symbol
  end

  def to_s()
    if exit_date.nil?
      format('OPEN %s %d shares@$%3.2f', ticker.symbol, quantity, entry_price)
    else
      format('CLOSE %s %d shares@$%3.2f on %s gain: $%4.2f (%3.1f%%)', ticker.symbol, quantity, exit_price, exit_date.to_formatted_s(:ymd), roi*quantity, roi)
    end
  end

  def close(order)
    @@open_position_count -= 1
    attrs = OpenStruct.new
    attrs.xorder_id = order.id
    attrs.exit_date = order.filled_at
    attrs.days_held = SimPosition.trading_days_between(entry_date, attrs.exit_date)
    attrs.exit_price = order.fill_price
    attrs.roi = ((attrs.exit_price - entry_price) / entry_price) * 100.0
    attrs.nreturn = attrs.roi / attrs.days_held
    update_attributes! attrs.marshal_dump
  end
end
