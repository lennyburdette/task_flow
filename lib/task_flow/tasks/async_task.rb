# encoding: utf-8
module TaskFlow
  class AsyncTask < Task
    def initialize(name, dependencies, connections, options, block)
      super(name, dependencies, connections, options.merge(timeout: 1), block)
    end

    def result(registry = nil)
      value(options[:timeout])
    end

    def task_class
      Concurrent::Future
    end
  end
end
