# encoding: utf-8
module TaskFlow
  class AsyncTask < Task
    cattr_reader(:task_executor) { Concurrent::CachedThreadPool.new }
    cattr_accessor(:default_options) { { timeout: 60 } }
    cattr_accessor(:task_options) { { executor: task_executor } }

    def result
      value
    end

    def task_class
      Concurrent::Future
    end
  end
end
