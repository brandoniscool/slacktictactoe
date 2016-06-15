load "active_record/railties/databases.rake"
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'
require "sinatra/activerecord/rake/activerecord_#{ActiveRecord::VERSION::MAJOR}"
require './app'

load "sinatra/activerecord/tasks.rake"

ActiveRecord::Base.logger = nil
