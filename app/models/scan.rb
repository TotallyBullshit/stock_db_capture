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
# Table name: scans
#
#  id          :integer(4)      not null, primary key
#  name        :string(255)
#  start_date  :date
#  end_date    :date
#  conditions  :text
#  description :string(255)
#  join        :string(255)
#  table_name  :string(255)
#  order_by    :string(255)
#  prefetch    :integer(4)
#  postfetch   :integer(4)
#  count       :integer(4)
#

# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

class Scan < ActiveRecord::Base

  include TradingCalendar

  has_many :positions, :dependent => :destroy
  has_and_belongs_to_many :tickers

  validates_uniqueness_of :name
  validates_presence_of :name, :start_date, :end_date

  before_save :clear_associations_if_dirty

  def clear_associations_if_dirty
    tickers.clear if changed?
  end

  def population_ids(repopulate=false, options={})
    logger = options[:logger]
    logger.info "Beginning population scan: #{name}..." if logger
    startt = Time.now
    ids = tickers_ids(repopulate, logger)

    delta = Time.now - startt
    logger.info "Matched #{tickers.count} tickers in #{Scan.format_et(delta)}" if logger
    return ids
  end

  def year()
    raise Exception, "year is different between start and end dates" if start_date.year != end_date.year
    start_date.year
  end

  def adjusted_start()
    prefetch.is_a?(Numeric) ? trading_date_from(start_date, -prefetch.to_i) : start_date
  end

  def adjusted_end()
    max_bar_date = DailyBar.maximum(:bardate, :conditions => { :ticker_id => 1674 }) #IBM
    adj_end = postfetch.is_a?(Numeric) ? trading_date_from(end_date, postfetch.to_i) : end_date
    [adj_end, max_bar_date].min
  end

  # TODO find a better name for this method
  def tickers_ids(repopulate=false, logger=nil)
    count = self.count.nil? ? "count(*) = #{trading_day_count(adjusted_start, adjusted_end)}" : "count(*) = #{self.count}"
    order = self.order_by ? " ORDER BY #{self.order_by}" : ' ORDER BY symbol'
    having = conditions ? "HAVING #{conditions} and #{count}" : "HAVING #{count}"

    sql = "SELECT #{table_name}.ticker_id FROM #{table_name} #{join} WHERE " +
          'delisted <> 1 AND ' +
          "bardate BETWEEN '#{adjusted_start.to_s(:db)}' AND '#{adjusted_end.to_s(:db)}' " +
          "GROUP BY ticker_id " + having + order

    if repopulate || tickers.empty?
      logger.info "Performing #{name} scan because it is not be done before or criterion have changed" if logger
      tickers.delete_all
      @tids = Scan.connection.select_values(sql)
      if @tids.empty?
        logger.error("No tickers returned from scan #{name}, SQL stmt:") if logger
        logger.error(sql) if logger
      end
      self.ticker_ids = @tids.map(&:to_i)
      ticker_ids
    else
      logger.info "Using *CACHED* values for scan #{name}" if logger
      ticker_ids
    end
  end

  class << self
    def find_by_name(keyword_or_string)
      first(:conditions => { :name => keyword_or_string.to_s.downcase})
    end

    def find_by_year(year)
      first(:conditions => { :name => "year_#{year}" })
    end

    #--------------------------------------------------------------------------------------------------------------------
    # fromat elasped time values. Does some pretty printing about delegating part of the base unit (seconds) into minutes.
    # Future revs where we backtest an entire decade we will, no doubt include hours as part of the time base
    # FIXME!! this should really be in a utilities module that get's extended in this class!!
    #--------------------------------------------------------------------------------------------------------------------
    def format_et(seconds)
      if seconds > 60.0 and seconds < 120.0
        format('%d minute and %d seconds', (seconds/60).floor, seconds.to_i % 60)
      elsif seconds > 120.0
        format('%d minutes and %d seconds', (seconds/60).floor, seconds.to_i % 60)
      else
        format('%2.2f seconds', seconds)
      end
    end
  end
end
