# encoding: utf-8
require 'task_flow/task'

module TaskFlow
  class TaskPrototype
    attr_reader :type, :name, :dependencies, :options, :block
    def initialize(type, name, dependencies, options, block)
      @type         = type
      @name         = name
      @dependencies = Array.wrap(dependencies || [])
      @options      = options || {}
      @block        = block
    end

    def connections
      dependencies + Array.wrap(options[:between])
    end

    def instance
      task_class = "#{type}_task".classify.to_sym
      TaskFlow.const_get(task_class).new(name, dependencies, connections, options, block)
    end
  end
end
