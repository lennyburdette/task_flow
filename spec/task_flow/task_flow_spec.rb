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

      async :timeout, timeout: 0.1 do
        sleep(1)
        :should_not_appear
      end

      async :timeout_swallowed, timeout: 0.1, on_exception: :swallowed do
        sleep(1)
        :should_not_appear
      end

      sync :from_timeout, :timeout do
        :should_raise_exception
      end

      sync :from_timeout_handled, :timeout, on_exception: :handled do
        :should_return_handled
      end

      sync :from_timeout_swallowed, :timeout_swallowed do |inputs|
        inputs[:timeout_swallowed]
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

    it 'raises a timeout' do
      expect do
        ExceptionHandlingCase.new.futures(:from_timeout).from_timeout
      end.to raise_error(Timeout::Error)
    end

    it 'handles a propagated timeout' do
      expect(ExceptionHandlingCase.new.futures(:from_timeout_handled).from_timeout_handled).to eq :handled
    end

    it 'swallows a timeout at the source' do
      expect(
        ExceptionHandlingCase.new
        .futures(:from_timeout_swallowed).from_timeout_swallowed
      ).to eq :swallowed
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

      async :longer_option do
        sleep(0.1)
        :foo
      end

      branch :option do |_, context|
        if context[:pick] == :long
          :longer_option
        else
          'Shorter one'
        end
      end
    end

    it 'conditionally executes tasks based on the result of another task' do
      expect(BranchingUseCase.new(:one).futures(:result).result).to eq :one
      expect(BranchingUseCase.new(:two).futures(:result).result).to eq :two
      expect(BranchingUseCase.new(:long).futures(:option).option).to eq :foo
      expect(BranchingUseCase.new(:short).futures(:option).option).to eq 'Shorter one'
    end
  end

  describe 'more complicated branching' do
    class ComplicatedBranchingUseCase
      include TaskFlow

      def initialize(context)
        @context = context
      end

      async :leaf do
        sleep(0.1)
        'from leaf'
      end

      async :other_leaf do
        sleep(0.1)
        'no one cares about this but it has to run'
      end

      async :async, depends: [:leaf, :other_leaf] do |inputs|
        inputs[:leaf]
      end

      branch :branch, between: :async do |inputs, context|
        context
      end

      async :result, depends: :branch do |inputs|
        inputs[:branch]
      end
    end

    it 'fires off a conditional subtree' do
      expect(ComplicatedBranchingUseCase.new(:async).futures(:result).result).to eq 'from leaf'
    end
  end

  describe 'instrumentation' do
    class InstrumentedUseCase
      include TaskFlow

      async :one do
        sleep(0.1)
        1
      end

      async :two, :one, on_exception: 2 do
        sleep(0.1)
        fail 'testing'
      end

      sync :result, :two do |inputs|
        inputs[:two]
      end
    end

    let(:events) { Hash.new { [] } }

    around do |spec|
      subscriber = ->(name, start, finish, id, payload) do
        events[name] = [name, start, finish, id, payload]
      end
      ActiveSupport::Notifications.subscribed(subscriber, /task_flow$/) do
        spec.run
      end
    end

    it 'reports tasks, exceptions, and result timing' do
      InstrumentedUseCase.new.futures(:result).result
      expect(events.key?('one.tasks.task_flow')).to be_true
      expect(events['two.exceptions.task_flow'].last[:swallowed]).to be_true
      duration = events['result.results.task_flow'][2] - events['result.results.task_flow'][1]
      expect(duration).to be > 0.2
    end
  end
end
