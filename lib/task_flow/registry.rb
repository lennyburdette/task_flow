# encoding: utf-8
require 'task_flow/dependency_tree'

module TaskFlow
  class Registry
    attr_reader :storage
    def initialize(storage = {})
      @storage = storage
    end

    delegate :[], :[]=, :slice, to: :storage

    def dependency_tree
      @dependency_tree ||= DependencyTree.new.tap do |d|
        storage.each do |name, branch|
          d[name] = branch.dependencies
        end
      end
    end

    def subtree(*names)
      names.map { |name| dependency_tree.subtree(name) }.reduce(&:merge)
    end

    def sorted(*branches)
      target = branches.any? ? subtree(*branches) : dependency_tree
      target.tsort.map { |name| storage[name] }
    end

    def instances(context)
      all = storage.reduce({}) do |acc, (k, v)|
        acc.merge(k => v.instance)
      end

      all.each do |name, instance|
        instance.create_task(all, context)
      end

      self.class.new(all)
    end
  end
end
