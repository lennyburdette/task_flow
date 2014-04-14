# encoding: utf-8
require 'task_flow/present'

module TaskFlow
  class BranchTask < Task
    attr_accessor :child_task

    def value
      event.wait
      child_task.value if child_task
    end

    def update(time, value, reason)
      event.set
    end

    def create_task(registry, context = nil)
      @task ||= begin
        inputs = registry.slice(*dependencies)

        Present.new do
          instrument("#{name}.tasks.task_flow") do
            values = inputs.reduce({}) do |acc, (name, input)|
              acc.merge(name => input.value)
            end
            child = block.call(values, context)

            if registry[child]
              self.child_task = registry[child]
              registry[child].add_observer(self)
              registry[child].fire
            else
              event.set
              nil
            end
          end
        end
      end
    end
  end
end
