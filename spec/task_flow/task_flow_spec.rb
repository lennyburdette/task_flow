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
        inputs.one * 3
      end

      async :four, depends: :two do |inputs|
        sleep(0.1)
        inputs.two * inputs.two
      end

      sync :seven, depends: [:three, :four] do |inputs|
        inputs.values.reduce(&:+)
      end

      sync :failure, depends: :one do |inputs|
        inputs.this_doesnt_exist
      end
    end

    it 'creates a dependency tree' do
      expect(SimpleUseCase.registry.dependency_tree.to_hash).to eq(
        one: [],
        two: [],
        three: [:one],
        four: [:two],
        seven: [:three, :four],
        failure: [:one],
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

    it 'complains when you access an task value that doesn\'t exist' do
      expect do
        SimpleUseCase.new.futures(:failure).failure
      end.to raise_error(NoMethodError)
    end
  end

  describe 'exception handling' do
    class ExceptionHandlingCase
      include TaskFlow

      async :error do
        fail StandardError
      end

      sync :propagates_error, :error do |inputs|
        inputs.error
      end

      async :caught_error, on_exception: -> { :handled } do
        fail StandardError
      end

      sync :handles_error, :caught_error do |inputs|
        inputs.caught_error
      end

      async :timeout, timeout: 0.1 do
        sleep(3)
        :should_not_appear
      end

      sync :from_timeout, :timeout do
        :should_raise_exception
      end

      sync :from_timeout_swallowed, :timeout, on_exception: :swallowed do |inputs|
        inputs.timeout
      end

      async :task_never_ends do
        while true
        end
      end

      sync :handle_hung_task, depends: :task_never_ends, timeout: 0.1 do |inputs|
      end

      async :async_handle_hung_task, depends: :task_never_ends, timeout: 0.1 do |inputs|
      end

      branch :branch_handle_hung_task, between: :task_never_ends, timeout: 0.1 do
        :task_never_ends
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

    it 'swallows a timeout at the source' do
      expect(
        ExceptionHandlingCase.new.futures(:from_timeout_swallowed).from_timeout_swallowed
      ).to eq :swallowed
    end

    it 'times out on extremely long tasks' do
      expect do
        ExceptionHandlingCase.new
        .futures(:handle_hung_task).handle_hung_task
      end.to raise_error(Timeout::Error)
    end

    it 'times out on extremely long tasks, async version' do
      expect do
        ExceptionHandlingCase.new
        .futures(:async_handle_hung_task).async_handle_hung_task
      end.to raise_error(Timeout::Error)
    end

    it 'times out on extremely long tasks, branch version' do
      expect do
        ExceptionHandlingCase.new
        .futures(:branch_handle_hung_task).branch_handle_hung_task
      end.to raise_error(Timeout::Error)
    end
  end

  describe 'thread management' do
    class ThreadDeathUseCase
      include TaskFlow

      async :death do
        Thread.exit
      end

      async :horseman, depends: :death do |inputs|
        inputs.death
        "neigh"
      end

      async :reap, depends: [:death, :horseman] do |inputs|
        inputs.horseman
      end

      sync :grim_reaper, depends: :reap, timeout: 0.1 do |inputs|
        inputs.reap
        "avoided-death"
      end
    end

    it 'doesn\'t get locked up' do
      expect do
        ThreadDeathUseCase.new.futures(:grim_reaper).grim_reaper
      end.to raise_error(Timeout::Error)
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

      branch :pick_one, between: [:expensive_one, :expensive_two] do |_, context|
        "expensive_#{context[:pick]}".to_sym
      end

      sync :result, :pick_one do |inputs|
        inputs.pick_one
      end

      async :longer_option do
        sleep(0.1)
        :foo
      end

      branch :option, between: :longer_option do |_, context|
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
        'from leaf'
      end

      async :other_leaf do
        'no one cares about this but it has to run'
      end

      async :async, depends: [:leaf, :other_leaf] do |inputs|
        inputs.leaf
      end

      branch :branch, between: :async do |inputs, context|
        context
      end

      async :result, depends: :branch do |inputs|
        inputs.branch
      end
    end

    it 'fires off a conditional subtree' do
      expect(ComplicatedBranchingUseCase.new(:async).futures(:result).result).to eq 'from leaf'
    end
  end

  describe 'even more complicated branching' do
    class BranchDepsUseCase
      include TaskFlow

      async(:a1) { sleep(0.1) }
      async(:b1) { sleep(0.1) }
      async(:c1) { sleep(0.1) }

      sync(:a, :a1) { 'a' }
      sync(:b, :a, :b1) { |i| "#{i.a}b" }
      sync(:c, :b, :c1) { |i| "#{i.b}c" }

      async(:d, :c) { |i| "#{i.c}d" }
      branch(:e, :c, between: :d) { |i| :d }
    end

    it 'fires off dependencies only once' do
      expect(BranchDepsUseCase.new.futures(:e).e).to eq 'abcd'
    end
  end

  describe 'unused tasks' do
    class BranchDepsUseCase
      include TaskFlow

      async(:a1) { sleep(0.1) }
      async(:b1) { sleep(0.1) }
      async(:c1) { sleep(0.1) }

      sync(:a, :a1) { 'a' }
      sync(:b, :a, :b1) { |i| "#{i.a}b" }
      sync(:c, :b, :c1) { |i| "#{i.b}c" }

      async(:d, :c) { |i| $unused_task_fired = true; "#{i.c}d" }
      branch(:f, :c, between: :d) { |i| 'f' }
    end

    before do
      $unused_task_fired = false
    end

    it 'do not fire' do
      expect(BranchDepsUseCase.new.futures(:f).f).to eq 'f'
      expect($unused_task_fired).to be false
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
        inputs.two
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
      expect(events.key?('one.tasks.task_flow')).to be true
      expect(events['two.exceptions.task_flow'].last[:swallowed]).to be true
      duration = events['result.results.task_flow'][2] - events['result.results.task_flow'][1]
      expect(duration).to be > 0.2
    end
  end

  if RUBY_PLATFORM == 'java'
    describe 'java exception handling' do
      class JavaExceptionUseCase
        include TaskFlow

        sync :fails do
          # throws Java::JavaLang::IllegalArgumentException
          java.util.concurrent.ThreadPoolExecutor.new(
            100, 1, 0,
            java.util.concurrent.TimeUnit::SECONDS,
            java.util.concurrent.SynchronousQueue.new,
            java.util.concurrent.ThreadPoolExecutor::AbortPolicy)
        end
      end

      it 'wraps java exceptions when re-raising' do
        expect do
          JavaExceptionUseCase.new.futures(:fails).fails
        end.to raise_error(RuntimeError)
      end
    end
  end
end
