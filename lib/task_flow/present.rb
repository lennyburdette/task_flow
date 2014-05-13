# encoding: utf-8
module TaskFlow
  class Present < Concurrent::Future
    EXECUTOR = Concurrent::ImmediateExecutor.new

    def initialize(*args)
      super
      @executor = EXECUTOR
    end
  end
end