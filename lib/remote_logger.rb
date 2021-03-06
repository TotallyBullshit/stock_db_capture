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
require '../config/micro-environment' if __FILE__ == $0
require 'drb/drb'
require 'monitor'
require 'class_helpers'
#
# Encapsulates the "remote logger" drb protocol. A RemoteLogger is is a DrbObject which is generate by the remote_logger
# daemon. The main idea is that when we are running distributed applicatons we want each one to send messages to one
# log file. This extends to distributed apps running on seperate machines. The implementation is such that the remote_logger
# daemon is actually a Factor of remote loggers. When a logger is instantiated a drb call is made to the daemon requesting
# a new logger. If the logger has the same name and basedir as one previously generated (and is still open), that logger
# DrbObject is handed back, otherwise a RemoteLogger is constructed with the values of the given arguments, bound to a
# ActiveSupport::BufferedLogger which is bound to a file. It is importand that remote logger object be closed, otherwise
# they stay as live DrbObjects. Ostensibly this will happen if the finalizer is called upon garbagge collection. Your
# milage may vary.
#
class RemoteLogger

  URI = 'druby://localhost:9999'
  attr_reader :logger, :proc_id, :log_name

  cattr_accessor :remote_logger_factory
  delegate :level, :level=, :autoflushing, :autoflushing=, :flush, :to => :logger

  # Valid options are :autoflush => 5, :keep => false, :deverity => DEBUG
  def initialize(log_name='remote', basedir=File.join(RAILS_ROOT, 'log'), proc_id=0, options={})
    RemoteLogger.remote_logger_factory ||= DRbObject.new_with_uri(URI)
    @log_name = log_name
    @proc_id = proc_id
    @logger = remote_logger_factory.get_logger(log_name, basedir, options)
    @logger.extend(MonitorMixin)
    ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
  end

  private

  def log(msg, task_name, level, from=caller(3).first)
    logger.synchronize { logger.send(level, "#{level.to_s.upcase}\t[#{proc_id}:#{task_name}:#{from}] #{msg}") }
  end

  def raw_send(msg)
    logger.synchronize { logger.send(:info, msg); logger.flush() }
  end

  public

  def debug(msg, task_name='?')
    log(msg, task_name, :debug)
    flush()
  end

  def info(msg, task_name='?')
    log(msg, task_name, :info)
    flush()
  end

  def error(msg, task_name='?')
    log(msg, task_name, :error)
    flush()
  end

  def fatal(msg, task_name='?')
    log(msg, task_name, :fatal)
    flush()
  end

  def raw(msg)
    raw_send(msg)
  end

  def close()
    flush()
    RemoteLogger.remote_logger_factory.close(log_name)
  end

  class << self

    # Make sure remote log is closed properly on GC cleanup
    def finalize(id)
      OjbectSpace._id2ref(id).close()
    end

    def names
      remote_logger_factory.nil? ? [:unitialized] : remote_logger_factory.names()
    end
  end
end
#
# Unit and Capicity Test -- generates a flood of logger meesage
# just to see what the bandwidth and latency is.
#
if __FILE__ == $0
  threads = []
  threads.extend(MonitorMixin)
  rl_mutex = Object.new
  rl_mutex.extend(MonitorMixin)

  10.times do |i|
    Thread.new(i) do |i|
      threads.synchronize { threads.push(Thread.current) }
      $tl = Thread.current['logger'] = rl_mutex.synchronize { RemoteLogger.new(ARGV.first) }
      1000.times do
        case rand(3)
        when 0 then Thread.current['logger'].debug('this is a debug msg', i.to_s)
        when 1 then Thread.current['logger'].info('this is a info msg', i.to_s)
        when 2 then Thread.current['logger'].error('this is a error msg', i.to_s)
        when 3 then Thread.current['logger'].fatal('this is a fatal msg', i.to_s)
        end
      end
    end
  end
  threads.each { |thread| thread.join }
  $tl.close()
end
