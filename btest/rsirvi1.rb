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

#-----------------------------------------------------------------------------------------------------------------
# "Find all places where RSI gooes heads upwards of 30"
#------------------------------------------------------------------------------------------------------------------
source :rsi_trigger_14, :time_period => 14,:epass => 0..2, :result => [:rsi], :outputs => [:open_rsi_rvi] do |params, pass|
  rsi_vec = rsi(params).first
  indexes = under_threshold(20+pass*5, rsi_vec)
end

#-----------------------------------------------------------------------------------------------------------------
# Open all the positions generated by rsi_open_14
#------------------------------------------------------------------------------------------------------------------
open :open_rsi_rvi, :outputs => [:rsi_rvi_50], :template => :none do |params, position|
  position.open_using_trigger_values()
end

#-----------------------------------------------------------------------------------------------------------------
# "Find all places where RSI crosses 50 from below"
#------------------------------------------------------------------------------------------------------------------
filter :rsi_rvi_50, :outputs => [:exit_rsirvi], :time_period => 14, :window => 20, :result => :first, :template => :displace do |params, position|
  time, method = close_under_min(:rsi => params.merge(:threshold => 50),
                                 :rvi => params.merge(:threshold => 50))
  time = max_exit_date if time.nil?
  [time, value_at(time, :close), method, result_at(time, method)]
end

#-----------------------------------------------------------------------------------------------------------------
# Exit all positions that made it through the rsi_rvi_50 filter
#-----------------------------------------------------------------------------------------------------------------
exit :exit_rsirvi, :outputs => [:lagged_rsi_difference], :template => :none do |params, position|
  puts 'in exit_rsirvi1'
  results = take_results_for(:exit_rsirvi, position)
  puts 'in exit_rsirvi2'
#  puts "params: #{parms.inspect}"
#  puts "position: #{position}"
#  puts "results are #{results.join(', ')}"
#  exit_time, exit_price, indicator_id, indicator_value = take_results_for(:exit_rsirvi, position)
#  position.trigger_exit(exit_time, exit_price, indicator_id, indicator_value)
end

#-----------------------------------------------------------------------------------------------------------------
# "Close positions that have been triggered from an RVI or and RSI and whose indicatars have continued to climb until
# they peak out or level out"
#------------------------------------------------------------------------------------------------------------------
filter :lagged_rsi_difference, :outputs => [:rsirvi_close], :time_period => 14, :window => 10, :result => [:rsi], :template => :displace do |params, position|
  rsi_ary = rsi(params)
  rsi_ary2 = rsi_ary.dup
  rsi_ary.slice!(0, params[:window])
  dn = rsi_ary.diff().index { |diff| diff <= 0.0 }
  index = dn.nil? ? params[:window] : dn
  time = rindex2time(index)
  [time, value_at(time, :close), :rsi, result_at(time, :rsi)]
end

#-----------------------------------------------------------------------------------------------------------------
# Close the positions after they have been optimized by the prior filter
#-----------------------------------------------------------------------------------------------------------------
close :rsirvi_close, :outputs => [], :template => :none do |params, position|
  close_time, close_price, indicator_id, indicator_value = take_results_for(:rsiriv_close, position)
  position.close(close_time, close_price, indicator_id, indicator_value, :indicator => :rsimom)
end



liquid = "min(volume) >= 75000"
(2000..2000).each do |year|
  start_date = Date.civil(year, 1, 1)
  scan_name = "year_#{year}".to_sym
  end_date = start_date + 1.year - 1.day
  scan scan_name, :start_date =>  start_date, :end_date => end_date,
                  :conditions => liquid, :prefetch => Timeseries.prefetch_bars(:rsi, 14),
                  :join => 'LEFT OUTER JOIN tickers ON tickers.id = ticker_id',
                  :order_by => 'tickers.symbol', :outputs => [:rsi_trigger_14 ]
end

global_options :generate_stats => false, :truncate => true, :repopulate => true, :log_flags => [:basic],
               :prefetch => Timeseries.prefetch_bars(:rsi, 14), :postfetch => 20, :populate => true, :verbose => true

post_process do
#  make_sheet([:opening, :close, :high, :low, :volume], :pre_days => 1, :post_days => 30, :keep => true)
end

# Local Variables:
# mode:ruby
# End:
