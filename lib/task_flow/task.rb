# encoding: utf-8
require 'concurrent'
require 'active_support/notifications'

module TaskFlow
  class Task
    attr_reader :name, :dependencies, :options, :block, :task, :event
    delegate :add_observer, to: :task
    delegate :instrument, to: ActiveSupport::Notifications

    cattr_accessor(:default_options) { Hash.new }
    cattr_accessor(:task_options) { Hash.new }

    def initialize(name, dependencies, options, block)
      @name         = name
      @dependencies = dependencies
      @options      = options.reverse_merge(default_options)
      @block        = block
      @event        = Concurrent::Event.new
    end

    def create_task(registry, context = nil)
      @task ||= begin
        inputs = registry.slice(*dependencies)

        task_class.new(task_options) do
          instrument("#{name}.tasks.task_flow") do
            values = inputs.reduce({}) do |acc, (name, input)|
              acc.merge(name => input.value)
            end
            block.call(values, context)
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

    def value
      task.value(options[:timeout]) # possibly blocking

      case task.state
      when :fulfilled then task.value
      when :pending then (fail Timeout::Error, "#{name} timed out")
      else handle_exception
      end
    end

    def handle_exception
      instrument("#{name}.exception.task_flow")
      if options.key?(:on_exception)
        options[:on_exception].respond_to?(:call) ?
          options[:on_exception].call :
          options[:on_exception]
      else
        fail task.reason if task.reason
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
