# encoding: utf-8
module TaskFlow
  # API-compatible with Concurrent::Future with synchronous execution
  class Present
    attr_reader :reason
    def initialize(*args, &block)
      @observers = Concurrent::CopyOnWriteObserverSet.new
      @block = block
      @excuted = false
    end

    def add_observer(observer)
      if @executed
        observer.update(Time.now, @value, @reason)
      else
        @observers.add_observer(observer)
      end
    end

    def execute
      value
      @executed = true
      @observers.notify_and_delete_observers { [Time.now, @value, @reason] }
    end

    def value(timeout = nil)
      return @value if defined?(@value)
      return nil if defined?(@reason)
      @value = @block.call
    rescue => exception
      @reason = exception
    end

    def state
      return :pending unless @executed
      return :fulfilled if defined?(@value)
      :rejected
    end

    def pending?
      state == :pending
    end

    def fulfilled?
      state == :fulfilled
    end

    def rejected
      state == :rejected
    end
  end
end
