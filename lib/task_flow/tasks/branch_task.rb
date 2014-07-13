# encoding: utf-8
require 'task_flow/present'
require 'task_flow/task_values'

module TaskFlow
  class MissingBranchConnectionsError < StandardError; end

  class BranchTask < Task
    attr_accessor :child_task

    def initialize(name, dependencies, connections, options, block)
      unless Array.wrap(options[:between]).any?
        fail MissingBranchConnectionsError, 'Specify branch alternatives with `between: [:task1, :task2]`'
      end
      super
    end

    def value(timeout = nil)
      return child_task.value(timeout) if child_task
      task.value
    end

    def result(registry)
      event.wait(registry.cumulative_timeout(name))
      value(registry.cumulative_timeout(name))
    end

    def create_task(registry, context = nil)
      @task ||= begin
        inputs = registry.slice(*dependencies)

        Present.new do
          instrument("#{name}.tasks.task_flow") do
            begin
              block.call(TaskValues.new(inputs), context).tap do |result|
                if result.is_a?(Symbol) && registry[result]
                  self.child_task = registry[result]
                  registry.proxy_dependencies(from: name, to: result, instance: registry[result])
                  registry.fire_from_edges(result)
                end
              end
            ensure
              event.set
            end
          end
        end
      end
    end
  end
end
