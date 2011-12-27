require 'rubygems'
require 'bundler'

Bundler.require
Bundler.require(:test)

require 'minitest/autorun'
require 'mocha' # needs to be required after minitest so it has stub/mock methods mixed in

$LOAD_PATH << File.expand_path("../lib", File.dirname(__FILE__))

require 'resque/restricted_performer'

