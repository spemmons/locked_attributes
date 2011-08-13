ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] = File.dirname(__FILE__)

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

desc 'Default: run unit tests.'
task :default => :test
