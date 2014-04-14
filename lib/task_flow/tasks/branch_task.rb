# encoding: utf-8
require 'task_flow/present'

module TaskFlow
  class BranchTask < Task
    attr_accessor :child_task

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
            values = inputs.reduce({}) do |acc, (name, input)|
              acc.merge(name => input.value)
            end
            result = block.call(values, context)

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
