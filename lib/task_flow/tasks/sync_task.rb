# encoding: utf-8
require 'task_flow/present'

module TaskFlow
  class SyncTask < Task
    def result
      instrument("#{name}.results.task_flow") do
        event.wait(options[:timeout]) if dependencies.any?
        value
      end
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
