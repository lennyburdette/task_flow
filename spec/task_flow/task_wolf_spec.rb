# encoding: utf-8
require 'spec_helper'

describe TaskFlow do
  context 'simple use case' do
    class SimpleUseCase
      include TaskFlow

      async :one do
        sleep(0.1)
        1
      end

      sync :two do
        2
      end

      sync :three, depends: :one do |inputs|
        inputs[:one] * 3
      end

      async :four, depends: :two do |inputs|
        sleep(0.1)
        inputs[:two] * inputs[:two]
      end

      sync :seven, depends: [:three, :four] do |inputs|
        inputs.values.reduce(&:+)
      end
    end

    it 'creates a dependency tree' do
      expect(SimpleUseCase.registry.dependency_tree.to_hash).to eq(
        one: [],
        two: [],
        three: [:one],
        four: [:two],
        seven: [:three, :four]
      )
    end

    it 'evaluates' do
      expect(SimpleUseCase.new.futures(:seven).seven).to eq 7
    end

    it 'complains when you don\'t kick off futures' do
      expect do
        SimpleUseCase.new.seven
      end.to raise_error(TaskFlow::DependenciesNotPrepared)
    end
  end

  describe 'exception handling' do
    class ExceptionHandlingCase
      include TaskFlow

      async :error do
        fail StandardError
      end

      sync :propagates_error, :error do
        inputs[:error]
      end

      async :caught_error, on_exception: -> { :handled } do
        fail StandardError
      end

      sync :handles_error, :caught_error do |inputs|
        inputs[:caught_error]
      end
    end

    it 'propagates errors from threads' do
      expect do
        ExceptionHandlingCase.new.futures(:propagates_error).propagates_error
      end.to raise_error
    end

    it 'swallows errors when told to' do
      expect(ExceptionHandlingCase.new.futures(:handles_error).handles_error).to eq :handled
    end
  end

  describe 'branching' do
    class BranchingUseCase
      include TaskFlow

      def initialize(pick)
        @context = { pick: pick }
      end

      async :expensive_one do
        sleep(0.1)
        :one
      end

      async :expensive_two do
        sleep(0.1)
        :two
      end

      branch :pick_one do |_, context|
        "expensive_#{context[:pick]}".to_sym
      end

      sync :result, :pick_one do |inputs|
        inputs[:pick_one]
      end
    end

    it 'conditionally executes tasks based on the result of another task' do
      expect(BranchingUseCase.new(:one).futures(:result).result).to eq :one
      expect(BranchingUseCase.new(:two).futures(:result).result).to eq :two
    end
  end
end
