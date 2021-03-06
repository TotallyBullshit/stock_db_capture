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

require 'rubygems'
require 'gsl'

module StockStatistics
  ATTRS = [ :opening, :high, :low, :close, :volume, :adj_close ]

  class StatSet

    SIMPLE_VALS = [:mean, :min, :max, :stddev, :absdev, :skew, :kurtosis, :cv]
    COMPLEX_VALS = [ :slope, :yinter, :cov00, :cov01, :cov11, :chisq ]


    attr_accessor :samples, :sample_count
    attr_accessor :mean, :min, :max, :stddev, :absdev, :skew, :kurtosis, :cv
    attr_accessor :slope, :yinter, :cov00, :cov01, :cov11, :chisq
    attr_accessor :unit_vector

    def initialize(samples, &block)
      self.samples = GSL::Vector.alloc(samples)
      self.sample_count = samples.length
      self.unit_vector = GSL::Vector.linspace(0, sample_count-1, sample_count-1)
      if block_given?
        yield self
      end
    end

    def compute_min
      self.min = samples.min
    end

    def compute_max
      self.max = samples.max
    end

    def compute_mean
      self.mean = samples.mean
    end

    def compute_stddev
      self.stddev = samples.sd(mean)
    end

    def compute_absdev
      self.absdev = samples.absdev(mean)
    end

    def compute_cv
      self.cv = self.stddev / self.mean
    end

    def compute_skew
      self.skew = samples.skew
    end

    def compute_kurtosis
      self.kurtosis = samples.kurtosis
    end

    def compute_regression
      self.yinter, self.slope, self.cov00, self.cov01, self.cov11, self.chisq = GSL::Fit::linear(unit_vector, samples)
    end

    def compute
      SIMPLE_VALS.each do |fcn|
        send("compute_#{fcn}")
      end
      compute_regression
      self
    end

    def to_hash
      all_vals = SIMPLE_VALS + COMPLEX_VALS + [:sample_count]
      all_vals.inject({}) { |h, k| h[k] = send(k); h }
    end
  end

  def self.generate(tickers,  attrs=ATTRS, extra_conditions={ })
    tickers.each do |ticker|
      t = Ticker.find_by_symbol(ticker)
      if t and not (rows = DailyBar.all(:conditions => { :ticker_id => t.id }.merge(extra_conditions), :order => 'date')).empty?
        attrs.each do |attr|
          sample_vec = rows.collect(&attr)
          begin
            StatSet.new(sample_vec) do |ss|
              ss.compute()
              StatValue.create_row(attr.to_s, t, rows.first.date, rows.last.date, ss.to_hash)
            end
          rescue Exception => e
            puts "Invalid data for #{attr.to_s} " + e.message
          end
        end
      end
    end
  end

  # Return all stocks ordered by the coefficient of variance of the entire year.
  def self.most_volatile()
    sql = "select symbol from daily_bars join tickers on tickers.id = ticker_id group by ticker_id order by stddev(close)/avg(close) desc"
    vs = DailyBar.connection.select_values(sql)
    $cache.set('VolatileStocks', vs.join(','), nil, false)
    vs
  end

  def self.crunch_and_store
    vs = most_volatile()
    vs.each do |symbol|
      $cache.set('CurrentSymbol', symbol, nil, false)
      generate([symbol], [:close])
      1.upto(12) do |month|
        $cache.set('CurrentSymbol', "#{symbol}:#{month}", nil, false)
        generate(symbol, [:close], { :month => month })
      end
      puts symbol
    end
  end
end
