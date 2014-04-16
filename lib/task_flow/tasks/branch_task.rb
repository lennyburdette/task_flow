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

    def value
      return child_task.value if child_task
      task.value
    end
    alias_method :result, :value

    def create_task(registry, context = nil)
      @task ||= begin
        inputs = registry.slice(*dependencies)

        Present.new do
          instrument("#{name}.tasks.task_flow") do
            result = block.call(TaskValues.new(inputs), context)

            if result.is_a?(Symbol) && registry[result]
              self.child_task = registry[result]

              registry.find_parents(name).each do |input|
                input.add_dependency(registry[result])
              end

              registry.fire_from_edges(result)
            else
              result
            end
          end
        end
      end
    end
  end
end
