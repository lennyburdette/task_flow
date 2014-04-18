# encoding: utf-8
module TaskFlow
  class AsyncTask < Task
    def result
      value(options[:timeout])
    end

    def task_class
      Concurrent::Future
    end
  end
end
