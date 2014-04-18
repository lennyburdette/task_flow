# encoding: utf-8
require 'active_support/notifications'
require 'concurrent'
require 'timeout'
require 'task_flow/task_values'

module Concurrent
  class DependencyCounter # :nodoc:
    def increment
      @counter.increment
    end
  end
end

module TaskFlow
  class Task
    attr_reader :name, :dependencies, :connections, :options, :block, :task, :event
    delegate :add_observer, to: :task
    delegate :instrument, to: ActiveSupport::Notifications

    cattr_accessor(:default_options) { { timeout: 30 } }
    cattr_accessor(:exception_reporter) { ->(*args) {} }

    def initialize(name, dependencies, connections, options, block)
      @name         = name
      @dependencies = dependencies
      @connections  = connections
      @options      = options.reverse_merge(default_options)
      @block        = block
      @event        = Concurrent::Event.new
    end

    def create_task(registry, context = nil)
      @task ||= begin
        inputs = registry.slice(*dependencies)

        task_class.new do
          Timeout::timeout(options[:timeout]) do
            instrument("#{name}.tasks.task_flow") do
              block.call(TaskValues.new(inputs), context)
            end
          end
        end
      end
    end

    def connect(registry)
      return self if @connected || dependencies.empty?
      inputs = registry.slice(*dependencies)

      if inputs.any?
        inputs.each do |name, input|
          input.add_observer(dependency_observer)
        end
      end

      @connected = true
      self
    end

    def dependency_observer
      @dependency_observer ||= Concurrent::DependencyCounter.new(dependencies.size) { task.execute }
    end

    def add_dependency(input)
      dependency_observer.increment
      input.add_observer(dependency_observer)
    end

    def value(timeout = nil)
      task.value(timeout || options[:timeout]) # possibly blocking

      case task.state
      when :fulfilled then task.value
      when :pending, :unscheduled then (raise Timeout::Error, "#{name} timed out")
      else (raise task.reason if task.reason)
      end
    rescue Exception => e
      handle_exception(e)
    end

    def handle_exception(exception)
      swallow = options.key?(:on_exception)
      exception_reporter.call(name, exception, swallow)
      instrument("#{name}.exceptions.task_flow", exception: exception, swallowed: swallow)

      if swallow
        options[:on_exception].respond_to?(:call) ?
          options[:on_exception].call :
          options[:on_exception]
      else
        fail exception
      end
    end

    def fire
      task.execute if leaf?
    end

    def leaf?
      dependencies.empty?
    end
  end
end

require 'task_flow/tasks/async_task'
require 'task_flow/tasks/sync_task'
require 'task_flow/tasks/branch_task'
