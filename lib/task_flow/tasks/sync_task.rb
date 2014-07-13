# encoding: utf-8
require 'task_flow/present'

module TaskFlow
  class SyncTask < Task
    def result(registry)
      instrument("#{name}.results.task_flow") do
        return value unless dependencies.any?

        timeouts = registry.cumulative_timeout(name)
        if event.wait(timeouts)
          value
        else
          reasons = registry.dependency_states(name).map do |name, state|
            case state
            when :pending then "\t#{name} never finished"
            when :unscheduled then "\t#{name} never started"
            end
          end
          fail Timeout::Error, "#{name} result timed out because:\n#{reasons.compact.join("\n")}"
        end
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
