# encoding: utf-8
module TaskFlow
  class TaskValues
    def initialize(inputs)
      @values = inputs.reduce({}) do |acc, (name, input)|
        acc.merge(name => input.value)
      end
    end

    def values
      @values.values
    end

    def method_missing(method_name, *args, &block)
      @values.key?(method_name) ? @values[method_name] : super
    end

    def respond_to_missing(method_name, include_private = false)
      @values.key?(method_name) || super
    end
  end
end
