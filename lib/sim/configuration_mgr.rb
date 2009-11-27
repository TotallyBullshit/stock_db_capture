# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

require 'ostruct'
require 'yaml'
require 'stringio'

module Kernel
  private
  def pp_s(*objs)
      s = StringIO.new
      objs.each {|obj|
        PP.pp(obj, s)
      }
      s.rewind
      s.read
  end
  module_function :pp_s
end

module Sim
  class ConfigurationMgr

    attr_reader :options

    def initialize(sm, ostruct)
      if ostruct.apply_defaults
        master_config, local_config = {}, {}
        master_path = File.join(RAILS_ROOT, 'lib', 'sim', 'config.yml')
        user_path = File.join(ENV['USER'], '.satvatr', 'simulator.yml')
        master_config = YAML.load_file(master_path) if File.exists? master_path
        local_config = YAML.load_file(user_path) if File.exists? user_path
        default_options = master_config.merge(local_config).inject({}) { |m, pair| m[pair.first.to_sym] = pair.second; m}
        @options = OpenStruct.new(default_options.merge(ostruct.marshal_dump))
      else
        @options = ostruct
      end
      sm.log("Config Values for Simulation are: \n\n")
      sm.log(pretty_options(options.marshal_dump))
    end

    def cval(key)
      options.send(key)
    end

    def pretty_options(option_hash)
      option_hash.to_yaml
    end
  end
end
