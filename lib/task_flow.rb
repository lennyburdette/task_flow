require 'active_support/concern'
require 'active_support/core_ext'
require 'task_flow/registry'
require 'task_flow/task_prototype'
require 'task_flow/version'

module TaskFlow
  extend ActiveSupport::Concern

  class DependenciesNotPrepared < StandardError; end

  included do
    cattr_accessor(:registry) { Registry.new }
    attr_reader :context
  end

  module ClassMethods
    def task(type, name, *dependencies, &block)
      options = dependencies.extract_options!
      dependencies = options[:depends] || options[:depends_on] unless dependencies.any?
      registry[name] = TaskPrototype.new(type, name, dependencies, options, block)
    end

    def sync(name, *dependencies, &block)
      task(:sync, name, *dependencies, &block)
    end

    def async(name, *dependencies, &block)
      task(:async, name, *dependencies, &block)
    end

    def branch(name, *dependencies, &block)
      task(:branch, name, *dependencies, &block)
    end
  end

  def instance_registry
    @instance_registry ||= registry.instances(context)
  end

  def futures(*names)
    instance_registry.connect(*names)
    instance_registry.fire_from_edges(*names)

    self
  end

  def method_missing(method_name, *args, &block)
    case instance_registry.task_state(method_name)
    when :ready then instance_registry[method_name].result
    when :unavailable then fail DependenciesNotPrepared, "Call `#futures(:#{method_name})` first"
    else super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    instance_registry[method_name].present? || super
  end
end
