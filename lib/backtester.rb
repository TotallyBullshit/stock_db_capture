# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

require 'analytics/maker'
require 'analytics/builder'
require 'population/builder'
require 'population/maker'
require 'backtest/maker'
require 'backtest/builder'
require 'yaml'

require 'rubygems'
require 'ruby-debug'

class BacktestException < Exception
  def initialize(msg)
    super(msg)
  end
end

class Backtester

  attr_accessor :ticker, :ts, :result_hash, :meta_data_hash
  attr_reader :pnames, :sname, :desc, :options, :post_process, :close_buffer, :entry_cache, :ts_cache
  attr_reader :strategy, :opening, :closing, :scan, :stop_loss, :tid_array, :date_range

  def initialize(strategy_name, population_names, description, options, &block)
    @options = options.reverse_merge :populate => true, :resolution => 1.day, :plot_results => false, :close_buffer => 30
    @sname = strategy_name
    @pnames = population_names
    @desc = description
    @close_buffer = @options[:close_buffer]
    @positions = []
    @post_process = block
    @entry_cache = {}
    @ts_cache = {}

    raise BacktestException.new("Cannot find strategy: #{sname.to_s}") unless $analytics.has_pair?(sname)

    pnames.each do |pname|
      raise BacktestException.new("Cannot find population: #{pname.to_s}") if Scan.find_by_name(pname).nil?
    end
  end

  def run(logger)
    $logger = logger
    logger.info "Processing backtest of #{sname} against #{pnames.join(', ')}"
    @strategy = Strategy.find_by_name(sname)
    @opening = $analytics.find_opening(sname)
    @closing = $analytics.find_closing(sname)
    @stop_loss = $analytics.find_stop_loss
    # Loop through all of the populations given for this backtest
    startt = Time.now
    for scan_name in pnames
      @scan = Scan.find_by_name(scan_name)
      # FIXME when a backtest specifies a different set of options, e.g. (:price => :close) we should
      # FIXME invalidate any cached posistions (including and exspecially scans_strategies because the positions will have
      # FIXME totally different values
      if strategy.scan_ids.include?(scan.id)
        #TODO wipe all the scans associated with this position if position changed
        logger.info "Using CACHED positions"
        next
      else
        logger.info "Recomputing Positions"
      end
      @tid_array = scan.tickers_ids
      sdate = scan.start_date
      edate = scan.end_date
      @date_range = sdate..edate
      # Foreach ticker in the population, create a timeseries for the date range given with the population
      # and run the analysis given with the strategy on said timeseries
      for pass in 0..2
        pass_count = 0
        for tid in tid_array
          @ticker = Ticker.find tid
          begin
            if ts_cache[tid].nil?
              ts = Timeseries.new(ticker.symbol, date_range, options[:resolution], options)
              ts_cache[tid] = ts
            elsif ts_cache[tid]
              ts = ts_cache[tid]
            end
          rescue TimeseriesException => e
            logger.error("#{ticker.symbol} has missing dates, skipping...")
            logger.error("Error: #{e.to_s}")
            ts_cache[tid] = false
            next
          end
          @entry_cache[tid] ||= []
          pass_count += open_positions(ts, opening.params, pass)
        end
        $logger.info(">>>>> Entries for pass #{pass}: #{pass_count} <<<<<<<<<<<<<<<<")
      end
      strategy.scans << scan
    end
    endt = Time.now
    delta = endt - startt
    deltam = delta/60.0
    logger.info "Open position elapsed time: #{deltam} minutes"
    #
    # Perform stop loss analysis if it was specified in the analytics section of the backtest config
    #
    unless stop_loss.nil?
      logger.info "Beginning close stop loss analysis..."
      startt = Time.now
      open_positions = strategy.positions.find(:all, :conditions => 'nreturn is null')
      open_positions.each do |p|
        tstop(p, stop_loss.threshold, stop_loss.options)
      end
    end
    endt = Time.now
    delta = endt - startt
    deltam = delta/60.0
    logger.info "Backtest (stop loss analysys) elapsed time: #{deltam} minutes"

    # Now closes the posisitons that we just openned by running the block associated with the backtest
    # The purpose for "apply" kind of backtest is to open positions based upon the criterion given
    # in the "analytics" section and then close them be evaluating the block associated with the "apply"
    # If everybody does what they're supposed to do, we end up with a set of positions that have been openned
    # and closed, giving the raw data for the analysis of the backtest
    logger.info "Beginning close positions analysis..."
    startt = Time.now
    pass = 0
    for pass in 0..5
      open_positions = strategy.positions.find(:all, :conditions => 'nreturn is null')
      pos_count = open_positions.length
      break if pos_count == 0
      counter = 1
      for position in open_positions
        p = close_position(position, pass)
        if p.exit_price.nil?
          logger.info "Pass(#{pass}) Position #{counter} of #{pos_count} #{p.entry_date.to_date}\t\t>#{close_buffer}\t#{p.entry_price}\t***.**\t0.000000"
        else
          logger.info "Pass(#{pass}) Position #{counter} of #{pos_count} #{p.entry_date.to_date}\t\t#{p.days_held}\t#{p.entry_price}\t#{p.exit_price}\t#{p.nreturn*100.0}"
        end
        counter += 1
      end
    end
    endt = Time.now
    delta = endt - startt
    deltam = delta/60.0
    logger.info "Backtest (close positions) elapsed time: #{deltam} minutes"
    post_process.call if post_process
  end

  # Run the analysis associated with the strategy which returns a set of indexes for which analysis is true
  # Convert this indexes to dates and open a position on that date at the openning price
  # Remember all of the positions openned for the second part of the backtest, which is to close
  # the open positions
  def open_positions(ts, params, pass)
      pass_count = 0
      begin
        open_indexes = ts.instance_exec(params, pass, &opening.block)
        for index in open_indexes
          next if index.nil? || @entry_cache[ts.ticker_id].include?(index)
          begin
            price = ts.value_at(index, :close)
            date = ts.index2time(index)
            debugger if date.nil?
            entry_trigger = ts.memo.result_for(index)
          rescue Exception => e
            puts e.to_s
            next
          end
          #TODO wipe all positions associated with the strategy if the strategy changes
          position = Position.open(scan, strategy, ticker, date, price, entry_trigger, params[:short], pass)
          entry_cache[ts.ticker_id] << index
          strategy.positions << position
          pass_count += 1
          position
        end
      rescue NoMethodError => e
        $logger.info e.message unless e.message =~ /to_v/ or $logger.nil?
      rescue TimeseriesException => e
        $logger.info e.message unless e.message =~ /recorded history/ or $logger.nil?
      rescue Exception => e
        $logger.info e.message
    end
    pass_count
  end

  def tstop(p, threshold_percent, options={})
    options.reverse_merge! :resolution => 30.minutes, :max_days => 30
    res = options[:resolution]
    trailing_days = options[:max_days]
    tratio = threshold_percent / 100.0
    etime = p.entry_date
    # determine if this position was entered during trading hours or at the end of the day
    # if so, calculate the bar_index (based upon resolution) of that day, or start with
    # the following day at index 0
    if etime.in_trade? && !etime.eod?
      sindex = ttime2index(etime, res)
      edate = p.entry_date.to_date
    else
      sindex = 0
      edate = trading_days_from(etime.to_date, 1).last
    end
    max_date = trading_days_from(edate, trailing_days).last
    # grab a timeseries at the given resolution from the entry date (or following day)
    # through the number of specified trailing days
    ts = Timeseries.new(p.ticker_id, edate..max_date, res, :pre_buffer => 0, :post_buffer => 0)
    bpd = ts.bars_per_day
    max_high = -1.0
    while sindex < ts.length
      max_high = -1.0 if sindex % bpd == 0
      high, low = ts.value_at(sindex, :high, :low)
      max_high = max_high > high ? max_high : high
      if (rratio = (max_high - low) / max_high) > tratio
        xtime = ts.index2time(sindex)
        xdate = xtime.to_date
        edate = p.entry_date.to_date
        days_held = Position.trading_day_count(edate, xdate)
        nreturn = days_held.zero? ? 0.0 : ((low - p.entry_price) / p.entry_price) / days_held
        nreturn *= -1.0 if p.short and nreturn != 0.0
        p.update_attributes!(:exit_price => low, :exit_date => xtime,
                             :days_held => days_held, :nreturn => nreturn,
                             :exit_trigger => rratio, :pass => -1)

        break;
      end
      sindex += 1
    end
    nil
  end

  # Close a position opened during the first phase of the backtest
  def close_position(p, pass)
    begin
      end_date = trading_days_from(p.entry_date, close_buffer).last
      ts = Timeseries.new(p.ticker_id, p.entry_date.to_date..end_date, 1.day,
                          :pre_buffer => 30, :post_buffer => 0)

      index = ts.instance_exec(closing.params, pass, &closing.block)

      if index.nil?
        p.update_attributes!(:exit_price => nil, :exit_date => nil,
                             :days_held => nil, :nreturn => nil)
      else
        price = ts.value_at(index, :close)
        exit_trigger = ts.memo.result_for(index)
        edate = p.entry_date.to_date
        xdate = ts.index2time(index)
        debugger if xdate.nil?
        days_held = Position.trading_day_count(edate, xdate)
        nreturn = days_held.zero? ? 0.0 : ((price - p.entry_price) / p.entry_price) / days_held
        nreturn *= -1.0 if p.short and nreturn != 0.0
        p.update_attributes!(:exit_price => price, :exit_date => xdate,
                             :days_held => days_held, :nreturn => nreturn,
                             :exit_trigger => exit_trigger, :pass => pass)
      end
    #rescue TimeseriesException => e
    #  if e.message =~ /recorded history/
    #    p.strategies.delete_all
    #    p.distroy
    #  end
    #  p = nil
    rescue Exception => e
      $logger.error "Exception Raised: #{e.to_s} skipping closure}" if $logger
      $logger.error p.inspect if $logger
    end
    p
  end
end
