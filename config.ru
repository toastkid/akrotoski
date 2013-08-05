# Rackup file for Thoth.

require 'rubygems'
require 'thoth'

#require "start"

module Thoth
  if ENV['RACK_ENV'] == 'development' || ENV['RAILS_ENV'] == 'development'
    trait[:mode] = :devel
  end

  Config.load(trait[:config_file])
  Config.load(trait[:admin_config_file])

  init_ramaze
  init_thoth
end

Ramaze.trait[:essentials].delete Ramaze::Adapter
Ramaze.start!
#Ramaze.start :force => true

run Ramaze::Adapter::Base
