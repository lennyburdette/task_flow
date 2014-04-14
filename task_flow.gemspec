# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'task_flow/version'

Gem::Specification.new do |spec|
  spec.name          = 'task_flow'
  spec.version       = TaskFlow::VERSION
  spec.authors       = ['Lenny Burdette']
  spec.email         = ['lenny.burdette@gmail.com']
  spec.summary       = %q{Declarative data flow and dependency management for short tasks.}
  spec.description   = %q{Separate async and synchronous tasks into small chunks, declare
    their interdependencies, and TaskFlow will sort out the most optimal execution order.}
  spec.homepage      = 'https://github.com/lennyburdette/task_flow'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '~> 4.1.0'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 0.5'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
