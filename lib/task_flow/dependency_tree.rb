# encoding: utf-8
require 'tsort'

module TaskFlow
  class DependencyTree
    include TSort
    attr_reader :tree

    delegate :[]=, :[], :each_key, :each, :reduce, :key?, to: :tree
    alias_method :to_hash, :tree
    alias_method :to_h, :tree

    def initialize(tree = {})
      @tree = tree.to_hash
    end

    alias_method :tsort_each_node, :each_key
    def tsort_each_child(node, &block)
      tree.fetch(node).each(&block)
    end

    def subtree(branch, accumulator = DependencyTree.new)
      accumulator.merge!(branch => tree[branch])
      tree[branch].each do |child|
        accumulator.merge!(subtree(child, accumulator))
      end
      accumulator
    end

    def combined_subtrees(*branches)
      branches.map { |name| subtree(name) }.reduce(&:merge)
    end

    def merge(other)
      self.class.new(tree.merge(other.to_hash))
    end

    def merge!(other)
      tree.merge!(other.to_hash)
    end
  end
end
