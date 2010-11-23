# encoding: utf-8

require 'rspec'

# Add lib/ to the path
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

RSpec.configure do |c|
  # Filter tests based on ruby version
  c.exclusion_filter = {
    :ruby => lambda { |version|
      !(RUBY_VERSION.to_s =~ /^#{version.to_s}/)
    }
  }
end
