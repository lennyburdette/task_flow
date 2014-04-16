# encoding: utf-8
module TaskFlow
  class AsyncTask < Task
    cattr_accessor(:default_options) { { timeout: 60 } }

    def result
      value
    end

    def task_class
      Concurrent::Future
    end
  end
end
