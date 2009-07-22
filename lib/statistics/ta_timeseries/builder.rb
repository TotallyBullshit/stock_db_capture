# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

module Statistics
  module TaTimeseries
    class TitsException < Exception
      def initialize(msg)
        super(msg)
      end
    end

    class Builder

      attr_reader :name, :options, :indicators

      def initialize(name, options={ })
        @name = name
        @options = options
        @indicators = []
      end

      def indicator(name, options)
        raise TitsException, "#{name} is not a support method of Timeseries" unless Timeseries.instance_methods.include? name.to_s
        raise TitsException, 'option :time_period missing' unless options.has_key? :time_period

        ind = TaSpec.create_spec(name, options[:time_period])

        @indicators << ind
      end
    end
  end
end
