# encoding: utf-8
module TaskFlow
  class AsyncTask < Task
    cattr_accessor(:default_options) { { timeout: 1 } }

    def result(registry = nil)
      value(options[:timeout])
    end

    def task_class
      Concurrent::Future
    end
  end
end
