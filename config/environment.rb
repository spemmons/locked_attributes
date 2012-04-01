RAILS_GEM_VERSION = '2.3.8' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.time_zone = 'UTC'
   config.action_controller.session = { :key => "dummy_key", :secret => "0123456789012345678901234567890123456789" }
end

# Normally this would be loaded by the plugin framework for an enclosing app
require File.join(File.dirname(__FILE__), '/../init.rb')
