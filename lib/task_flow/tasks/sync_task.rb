# encoding: utf-8
require 'task_flow/present'

module TaskFlow
  class SyncTask < Task
    def result
      event.wait if dependencies.any?
      value
    end

    def task_class
      Present
    end

    def dependency_observer
      @dependency_observer ||= Concurrent::DependencyCounter.new(dependencies.size) do
        task.execute
        event.set
      end
    end
  end
end
