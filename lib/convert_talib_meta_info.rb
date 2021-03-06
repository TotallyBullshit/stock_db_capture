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

module ConvertTalibMetaInfo


  def self.normalize_key(str)
    str.split.join('_').downcase.to_sym
  end

  def self.normalize_string(str)
    str.split.join('_').downcase
  end

  class FinancialFunctionArg
    attr_accessor :name

    def initialize(h)
      if h['name'] == 'open'
        self.name = 'opening'
      else
        self.name = h['name'].underscore
      end
    end
  end

  class FinancialFunctionInputArg < FinancialFunctionArg
    SPECIAL_ARGS = %w{ high low close open volume price }

    attr_accessor :type

    def initialize(h)
      super
      str = ConvertTalibMetaInfo.normalize_string(h['type'])

      if SPECIAL_ARGS.include? str
        self.type = [:internal, :vector, :implicit]
      elsif str == 'double_array'
        self.type = [:external, :vector, :double]
      else
        raise ArgumentError, "Unknown type for input arg #{self.name} of type: #{str}"
      end
    end
  end

  class FinancialFunctionOutputArg < FinancialFunctionArg

    attr_accessor :type, :graph_type

    def initialize(h)
      super
      str = ConvertTalibMetaInfo.normalize_string(h['type'])

      if str == 'double_array'
        self.type = [:output, :vector, :double]
      elsif str == 'integer_array'
        self.type = [:output, :vector, :integer]
      else
        raise ArgumentError, "Unknown type for output arg #{self.name} of type: #{str}"
      end

      if h['flags'] && h['flags']['flag']
        self.graph_type = ConvertTalibMetaInfo.normalize_key(h['flags']['flag'])
      end
    end
  end

  class FinancialFunctionOptArg < FinancialFunctionArg

    attr_accessor :type, :default, :description, :range

    def initialize(h)
      self.name = ConvertTalibMetaInfo.normalize_key(h['name'])
      self.type = ConvertTalibMetaInfo.normalize_key(h['type'])
      self.default = h['default_value']
      self.description = h['short_description']
      to_type = type == :integer ? :to_i : :to_f
      if h['range']
        min = h['range']['minimum'].send(to_type)
        max = h['range']['maximum'].send(to_type)
        self.range = min..max
      end
    end
  end

  class FinancialFunction
    attr_accessor :input_args, :output_args, :opt_args
    attr_accessor :name, :group, :description, :flags

    def initialize(h)
      self.name = h['abbreviation'].downcase.to_sym
      self.group = h['group_id']
      self.description = h['short_description']
      self.input_args = decode_input_args(h['required_input_arguments']['required_input_argument'])
      self.output_args = decode_output_args(h['output_arguments']['output_argument'])
      self.opt_args = decode_opt_args(h['optional_input_arguments']['optional_input_argument']) if h['optional_input_arguments']
      self.flags = decode_function_flags(h['flags']['flag']) if h['flags']
    end

    def stripped_output_names
      output_args.map { |arg| arg.name.gsub(/^out_([a-z0-9]+)/,'\1') }
    end

    def decode_input_args(h_or_array)
      h_or_array = [ h_or_array ] if h_or_array.class != Array
      h_or_array.map { |h| FinancialFunctionInputArg.new(h) }
    end

    def decode_output_args(h_or_array)
      h_or_array = [ h_or_array ] if h_or_array.class != Array
      h_or_array.map { |h| FinancialFunctionOutputArg.new(h) }
    end

    def decode_opt_args(h_or_array)
      h_or_array = [ h_or_array ] if h_or_array.class != Array
      h_or_array.map { |h| FinancialFunctionOptArg.new(h) }
    end

    def decode_function_flags(string_or_array)
      string_or_array = [ string_or_array ] if string_or_array.class != Array
      string_or_array.map { |string| ConvertTalibMetaInfo.normalize_key(string) }
    end

    def form_param_list(options)
      returning [] do |vec|
        opt_args.each do |arg|
          vec << (options.has_key?(arg.name) ? options[arg.name] : arg.default)
        end
      end
    end
  end

  def self.import_functions(fcn_h_array)
    out_h = { }
    fcn_h_array.each do |fcn_h|
      ff = FinancialFunction.new(fcn_h)
      out_h[ff.name] = ff
    end
    out_h
  end
end

class Array
  def underscore_keys!
    each do |elem|
      elem.underscore_keys! if elem.respond_to? :underscore_keys!
    end
  end
end

class Hash
  def underscore_keys!
    keys.each do |key|
      us = key.underscore
      if us != key
        value = fetch key
        value.underscore_keys! if value.respond_to? :underscore_keys!
        store us, value
        delete key
      end
    end
  end
end
