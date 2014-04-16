# encoding: utf-8
require 'bundler/setup'
Bundler.setup

require 'task_flow'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run_excluding slow: true
end
