# TaskFlow

Declarative data flow and dependency management for short tasks.

TaskFlow provides a declarative API for creating a directed acyclic graph of tasks. When you need the result of a task, it will execute the tasks in an optimal order, regardless of whether the task is synchronous or asynchrnous.

This library is inspired by [ConcurrentRuby's](https://github.com/jdantonio/concurrent-ruby) [Dataflow](https://github.com/jdantonio/concurrent-ruby/wiki/Dataflow) concept. TaskFlow's internals are similar but it's API is backwards, sort of.

## Installation

**I'm still developing this! You probably don't want to use it until I start incrementing the version number.**

Add this line to your application's Gemfile:

    gem 'task_flow'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install task_flow

## Usage

TaskFlow is a class mixin that provides three class methods: `sync`, `async`, and `branch`. Declare your tasks in a class:

```ruby
class PersonFetcher
  include TaskFlow

  def initalize(user_name)
    context = { user_name: user_name }
  end

  async :twitter do |_, context|
    Twitter.fetch_user(context[:user_name]) # kick off an expensive HTTP request
  end

  async :github do |_, context|
    Github.fetch_user(context[:user_name]) # kick off an expensive HTTP request
  end

  sync :person, depends: :github, :twitter do |inputs, context|
    Person.new(context[:user_name], profiles: [inputs.twitter, inputs.github])
  end
end
```

You can then create a new PersonFetcher and fire off all the tasks with `.futures`. Tasks without dependencies will fire first, concurrently if possible, and on completion will kick off tasks that depended on them, populating the `input` argument to the block.

```ruby
fetcher = PersonFetcher.new('lennyburdette').futures(:person)
```

When you call the `#person` instance method, it will block until the all the tasks complete.

```ruby
fetcher.person # => #<Person:0x0000000 @user_name="lennyburdette">
```

TaskFlow really shines when you have a complex web of asynchronous calls, some of which depend on the results of previous calls.

### Exception Handling

By default exceptions will bubble up through the tasks, but if you want to swallow an exception at the source (and handle the resulting data with, say, validation), add the `on_exception` option:

```ruby
async :request, on_exception: nil do
  # this may raise an exception, but when evaluated will just return nil
end
```

You can also set a timeout when blocking on a threaded call. By default it's 60 seconds:

```ruby
async :request, timeout: 2 do
  sleep(3) # will raise a Timeout::Error exception
end
```

## Contributing

1. Fork it ( https://github.com/lennyburdette/task_flow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
