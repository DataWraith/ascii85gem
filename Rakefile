require 'bundler'
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"

desc "Run all specs"
RSpec::Core::RakeTask.new(:specs)

task :default => :specs
