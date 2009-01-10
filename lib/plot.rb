require 'rubygems'
require 'gnuplot'
require 'rbgsl'
require 'gsl/gnuplot'

module Plot

  PLOT_TYPES = [ :line, :bar, :candlestick ]

  include GSL

  def plot_lines(index_range, timevec, *vecs_or_params)
    Gnuplot.open do |gp|
      Gnuplot::Plot.new( gp ) do |plot|

        plot.auto "x"
        plot.auto "y"
        plot.unset 'title'
        plot.unset 'xlabel'
        plot.unset 'ylabel'
        plot.pointsize 3
        plot.grid
        timevec = set_xvalues(plot, timevec[index_range])

        plot.data = []
        vecs_or_params.each do |vec|
          if vec.class == ParamBlock
            plot.data << Gnuplot::DataSet.new( [timevec, vec.to_a] ) {  |ds|  ds.using = "1:2"; ds.with = "lines" }
          else
            plot.data << Gnuplot::DataSet.new( [timevec, vec.to_a[index_range]] ) {  |ds|  ds.using = "1:2"; ds.notitle; ds.with = "lines" }
          end
        end
      end
      nil
    end
  end

  def plot_ts(gp, vecs, index_range, options)

    Gnuplot::Plot.new( gp ) do |plot|
      plot.auto "x"
      plot.auto "y"
      plot.unset "xlabel"
      plot.unset 'grid'
      plot.unset 'ylabel'
      plot.unset 'title'
      plot.set 'bmargin'
      plot.xtics 'scale default'
      plot.tmargin 0
#      plot.xlabel "Date from #{index2time(index_range.begin).to_s(:db)} to #{index2time(index_range.end).to_s(:db)} (#{len} points)"
      plot.origin options[:origin] if options[:origin]
      plot.size options[:size] if options[:size]

      timevec = set_xvalues(plot, self.timevec[index_range])
      withs = options[:with]

      plot.data = []
      vecs.each do |vec|
        with = withs.shift()
        plot.data << Gnuplot::DataSet.new( [timevec, vec.to_a[index_range]] ) {  |ds|  ds.using = "1:2"; ds.notitle; ds.with = with }
      end
    end
  end

  def plot_params(gp, param, options)
    Gnuplot::Plot.new( gp ) do |plot|
      plot.style 'line 1 lt 1 lw 1'
      plot.style 'line 2 lt 2 lw 1'
      plot.style 'line 3 lt 3 lw 1'
      plot.style 'line 4 lt 6 lw 1'
      plot.style 'increment user'
      plot.auto "x"
      plot.auto "y"
      plot.unset "xlabel"
      plot.unset 'grid'
      plot.unset 'ylabel'
      plot.unset 'title'
      plot.set 'bmargin'
      plot.xtics 'scale default'
      plot.tmargin 0
#      plot.xlabel "Date from #{index2time(index_range.begin).to_s(:db)} to #{index2time(index_range.end).to_s(:db)} (#{len} points)"
      plot.origin options[:origin] if options[:origin]
      plot.size options[:size] if options[:size]

      index_range, vecs = param.decode(:index_range, :vectors)

      timevec = set_xvalues(plot, self.timevec[index_range])

      plot.data = []
      vecs.each do |vec|
        plot.data << Gnuplot::DataSet.new( [timevec, vec.to_a] ) {  |ds|  ds.using = "1:2"; ds.notitle; ds.with = 'lines' }
      end
    end
  end

  def set_xvalues(plot, timevec)

    time_class = timevec.first.send(source_model.time_convert).class

    plot.xdata "time"
    if time_class == Date
      plot.timefmt '"%Y-%m-%d"'
      plot.format 'x "%m-%d\n%Y"'
      timevec.map { |t| t.to_date }
#      timevec.map { |t| '"'+t.strftime('%Y-%m-%d')+'"' }
    elsif time_class == Time || time_class == DateTime
      plot.timefmt '"%Y-%m-%d@%H:%M"'
      plot.format 'x "%m-%d\n%H:%M"'
      timevec.map { |t| '"'+time.strftime('%Y-%m-%d@%H:%M')+'"' }
    end
  end

  def aggregate(symbol, index_range, options)

    len = index_range.end - index_range.begin + 1

    Gnuplot.open do |gp|
      Gnuplot::Plot.new( gp ) do |plot|

        plot.auto "x"
        plot.auto "y"
        plot.title  "Candlestics for #{symbol}"
        plot.xlabel "Date from #{index2time(index_range.begin).to_s(:db)} to #{index2time(index_range.end).to_s(:db)} (#{len} points)"
        plot.ylabel 'OCHL'
        plot.pointsize 3
        plot.grid
 #       plot.bars "lw .5"
 #       plot.line "lw .5"
        plot.boxwidth ".5"
        plot.size "1,1"
        plot.origin "0,0"

        date = set_xvalues(plot, self.timevec[index_range])
        open = open_before_cast[index_range]
        close = close_before_cast[index_range]
        high = high_before_cast[index_range]
        low = low_before_cast[index_range]
#        volume = scale(volume_before_cast[index_range]) if options[:show_volume]

        plot.data = []
        plot.data << Gnuplot::DataSet.new( [date, open, low, high, close] ) {  |ds| ds.using="1:2:3:4:5"; ds.with = options[:with] }
#        plot.data << Gnuplot::DataSet.new( [date, volume] ) {  |ds|  ds.using = "1:2"; ds.with = "boxes" } if options[:show_volume]
      end
    end
    nil
  end

  def aggregate_base(plot, index_range, options)

    len = index_range.end - index_range.begin + 1

    plot.auto "x"
    plot.auto "y"
    plot.title  "Candlestics for #{symbol}"
    plot.ylabel 'OCHL'
    plot.pointsize 3
    plot.grid
    plot.bars 1.0
    plot.unset 'xtics'
    #       plot.bars "lw .5"
    #       plot.line "lw .5"
    plot.boxwidth ".5"
    plot.multiplot if options[:multiplot]
    plot.origin options[:origin] if options[:origin]
    plot.size options[:size] if options[:size]

    date = set_xvalues(plot, self.timevec[index_range])
    open = open_before_cast[index_range]
    close = close_before_cast[index_range]
    high = high_before_cast[index_range]
    low = low_before_cast[index_range]

    plot.data = []
    plot.data << Gnuplot::DataSet.new( [date, open, low, high, close] ) {  |ds| ds.using="1:2:3:4:5"; ds.notitle; ds.with = options[:with] }
  end

  def with_volume(index_range)
    multiplot(index_range, :multiplot => true, :origin => '0, .3', :size => '1, 0.7', :with => 'financebars') do |gp|
      plot_ts(gp, [volume], index_range, :origin => '0, 0', :size => '1, 0.3', :with => ['boxes'])
    end
  end

  def with_function(function)
    raise TimeseriesException.new("Cannot find memoized function: #{function}") if (pb = find_memo(function)).nil?
    multiplot(pb.index_range, :script => true, :prefix => function.to_s, :multiplot => true, :origin => '0, .3', :size => '1, 0.7', :with => pb.graph_type.nil? ? 'financebars' : pb.graph_type) do |gp|
      plot_params(gp, pb, :origin => '0, 0', :size => '1, 0.3', :with => ["lines"]*3)
    end
  end

  def multiplot(index_range, options, &block)
    Gnuplot.open(true, options.merge(:multiplot => true)) do |gp|
      Gnuplot::Plot.new( gp ) do |plot|
        aggregate_base(plot, index_range, options)
      end
      yield gp unless block.nil?
    end
  end

  def candlestick(symbol, index_range, options={})
    aggregate(symbol, index_range, options.merge(:with => 'candlesticks'))
  end

  def bar(symbol, index_range, options={})
    aggregate(symbol, index_range, options.merge(:with => 'financebar'))
  end

  def scale(vec)
    gvec = vec.to_gv
    max = gvec.max
    lmax = Math.log10(max)-1
    gvec.scale!(1/10**lmax)
    gvec.to_a
  end

  def histogram(symbol, attr)
    vhash = DailyClose.get_vectors(symbol, attr)
    gvec = vhash[attr].to_gv
    h = gvec.histogram(50)
    xvec = GSL::Vector.linspace(gvec.min, gvec.max, 50).to_a

    bins = h.bin.to_a

    Gnuplot.open do |gp|
      Gnuplot::Plot.new( gp ) do |plot|
        plot.style "histogram clustered gap 3"
        plot.style "fill solid 1.0 border -1"
        plot.xrange "[#{gvec.min}:#{gvec.max}]"

        plot.data = [ Gnuplot::DataSet.new( [xvec, bins] ) { |ds| ds.with = "boxes" } ]
      end
    end
    nil
  end

  def titleize(syms)
    syms.map { |sym| sym.to_s.titleize }.join(', ')
  end
end
