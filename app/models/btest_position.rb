# == Schema Information
# Schema version: 20100123024049
#
# Table name: btest_positions
#
#  id                :integer(4)      not null, primary key
#  ticker_id         :integer(4)
#  ettime            :datetime
#  etprice           :float
#  etival            :float
#  xttime            :datetime
#  xtprice           :float
#  xtival            :float
#  entry_date        :datetime
#  entry_price       :float
#  entry_ival        :float
#  exit_date         :datetime
#  exit_price        :float
#  exit_ival         :float
#  days_held         :integer(4)
#  nreturn           :float
#  logr              :float
#  short             :boolean(1)
#  closed            :boolean(1)
#  entry_pass        :integer(4)
#  roi               :float
#  num_shares        :integer(4)
#  etind_id          :integer(4)
#  xtind_id          :integer(4)
#  entry_trigger_id  :integer(4)
#  entry_strategy_id :integer(4)
#  exit_trigger_id   :integer(4)
#  exit_strategy_id  :integer(4)
#  scan_id           :integer(4)
#  consumed_margin   :float
#

# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

#require 'rubygems'
#require 'ruby-debug'

class BtestPosition < ActiveRecord::Base
  belongs_to :ticker
  belongs_to :entry_trigger
  belongs_to :exit_trigger
  belongs_to :entry_strategy
  belongs_to :exit_strategy
  belongs_to :scan
  belongs_to :etind, :class_name => 'Indicator'
  belongs_to :xtind, :class_name => 'Indicator'
  has_many :position_series, :dependent => :delete_all

  extend TradingCalendar

  def xtdays_held
    Position.trading_days_between(entry_date, xttime)
  end

  def xtroi
    (xtprice - entry_price) / entry_price
  end

  def exit_delta
    exit_price - xtprice
  end

  def exit_days_held
    Position.trading_days_between(xttime, exit_date)
  end

  def entry_delay
    BtestPosition.trading_days_between(ettime, entry_date)
  end

  class << self

    def entry_on(date)
      find.all(:conditions => ['date(entry_date) = ?', date])
    end

    def trigger_entry(ticker_id, trigger_time, trigger_price, ind_id, ival, pass, options={})
      begin
        attrs = { :ticker_id => ticker_id, :etprice => trigger_price, :ettime => trigger_time, :entry_pass => pass, :etind_id => ind_id, :etival => ival }
        attrs.merge!(:entry_date => trigger_time, :entry_price => trigger_price) if options[:next_pass] == false
        pos = create!(attrs)
      rescue ActiveRecord::RecordInvalid => e
        raise e.class, "You have a duplicate record (mostly likely you need to do a truncate of the old strategy) " if e.to_s =~ /already been taken/
        raise e
      end
      pos
    end

    def trigger_exit(position, trigger_time, trigger_price, indicator, ival, options={})
      begin
        ind_id = indicator.nil? ? nil : Indicator.lookup(indicator).id
        closed = options[:closed]
        ival = nil if ival.nil? or ival.nan?
        attrs = { :xtprice => trigger_price, :xttime => trigger_time, :xtind_id => ind_id, :xtival => ival, :closed => closed }
        attrs.merge!(:exit_price => trigger_price, :exit_date => trigger_time)
        pos = position.update_attributes! attrs
      rescue ActiveRecord::RecordInvalid => e
        raise e.class, "You have a duplicate record (mostly likely you need to do a truncate of the old strategy) " if e.to_s =~ /already been taken/
        raise e
      end
      pos
    end

    #
    # open a position that has been previously triggered. Note that because the entry date may have moved from the
    # trigger date this can result in a duplicate opening, for which we check first
    #
    def open(position, entry_time, entry_price, options={})
      short = options[:short]
      cmargin = (entry_price - position.etprice)/position.etprice
      position.update_attributes!(:entry_price => entry_price, :entry_date => entry_time,
                                  :num_shares => 1, :short => short, :consumed_margin => cmargin)
      position
    end

    def compute_derived_values()
      positions = find(:all, :conditions => { :days_held => nil} )
      for p in positions
        p.days_held = trading_days_between(p.entry_date, p.exit_date)
        p.roi = (p.exit_price - p.entry_price) / p.entry_price
        rreturn = p.exit_price / p.entry_price
        p.logr = Math.log(rreturn.zero? ? 0.0 : rreturn)
        p.nreturn = p.days_held.zero? ? 0.0 : p.roi / p.days_held
        p.nreturn *= -1.0 if p.short and p.nreturn != 0.0
        p.save!
      end
    end

    def close(position, exit_date, exit_price, exit_ival, options={})
      days_held = trading_days_between(position.entry_date, exit_date)
      exit_status = if exit_price.nil?
                      roi = rreturn = logr = nreturn = 0.0
                      true
                    else
                      roi = (exit_price - position.entry_price) / position.entry_price
                      rreturn = exit_price / position.entry_price
                      logr = Math.log(rreturn.zero? ? 0.0 : rreturn)
                      nreturn = days_held.zero? ? 0.0 : roi / days_held
                      nreturn *= -1.0 if position.short and nreturn != 0.0
                      false
                    end
      closed = options[:closed] == false ? nil : options[:closed]
      indicator_id = Indicator.lookup(options[:indicator]).id

      position.update_attributes!(:exit_price => exit_price, :exit_date => exit_date, :roi => roi,
                                  :xtind_id => indicator_id, :exit_ival => exit_ival,
                                  :days_held => days_held, :nreturn => nreturn, :logr => logr,
                                  :closed => closed)
      exit_status
    end
  end
end
