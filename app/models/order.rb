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
# == Schema Information
# Schema version: 20100205165537
#
# Table name: orders
#
#  id               :integer(4)      not null, primary key
#  txn              :string(3)       not null
#  otype            :string(3)       not null
#  expiration       :string(3)       not null
#  quantity         :integer(4)
#  placed_at        :datetime
#  filled_at        :datetime
#  activation_price :float
#  order_price      :float
#  fill_price       :float
#  ticker_id        :integer(4)      not null
#  sim_position_id  :integer(4)
#

# == Schema Information
# Schema version: 20091029212126
#
# Table name: orders
#
#  id               :integer(4)      not null, primary key
#  txn              :string(3)       not null
#  otype            :string(3)       not null
#  expiration       :string(3)       not null
#  quantity         :integer(4)
#  placed_at        :datetime
#  filled_at        :datetime
#  activation_price :float
#  order_price      :float
#  fill_price       :float
#  ticker_id        :integer(4)      not null
#  sim_position_id  :integer(4)
#

# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

require 'ostruct'

class Order < ActiveRecord::Base
  belongs_to :ticker
  belongs_to :sim_position

  TXN_TYPE = [ :buy, :sel, :btc, :ss ]
  ORDER_TYPE = [ :mkt, :lmt, :stm, :stl ]
  EXPIRATION = [ :day, :gtc ]

  class << self
    def make_buy(ticker_id, price, clock, options)
      order_ceiling = options[:order_ceiling]
      funds_available = options[:funds_available]
      order_charge = options[:order_charge]
      attrs = OpenStruct.new()
      attrs.txn = 'BUY'
      attrs.otype = 'MKT'
      attrs.expiration = 'DAY'
      attrs.ticker_id = ticker_id
      attrs.placed_at = clock
      attrs.filled_at = clock
      attrs.fill_price = price
      attrs.quantity = ([(funds_available - order_charge), order_ceiling].min / attrs.fill_price).floor
      attrs.order_price = attrs.quantity * attrs.fill_price + options[:order_charge]
      order = new(attrs.marshal_dump)
    end

    def make_sell(sim_position, price, clock, options)
      order_charge = options[:order_charge]
      attrs = OpenStruct.new()
      attrs.txn = 'SEL'
      attrs.otype = 'MKT'
      attrs.expiration = 'DAY'
      attrs.sim_position_id = sim_position.id
      attrs.ticker_id = sim_position.ticker_id
      attrs.quantity = sim_position.quantity
      attrs.placed_at = clock
      attrs.filled_at = clock
      attrs.fill_price = price
      attrs.order_price = sim_position.quantity * attrs.fill_price - options[:order_charge]
      order = new(attrs.marshal_dump)
    end

    def truncate()
      connection.execute("truncate #{self.to_s.tableize}")
    end
  end

  def event_time()
    filled_at
  end

  def position
    sim_position
  end

  def symbol
    ticker.symbol
  end

  def to_s()
    format('%s %s %s %d shares of %s @ $%3.2f = %5.2f', txn, otype, expiration, quantity, ticker.symbol, fill_price, order_price)
  end
end
