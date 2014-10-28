# encoding: utf-8
require 'task_flow/present'

module TaskFlow
  class SyncTask < Task
    def result(registry)
      instrument("#{name}.results.task_flow") do
        return value unless dependencies.any?

        timeout = registry.cumulative_timeout(name)
        value(timeout)
      end
    end

    def task_class
      Present
    end
  end
end
