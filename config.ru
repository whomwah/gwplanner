require 'rubygems'
require 'sinatra'
require 'rack/cache'
require 'app.rb'

use Rack::Cache, 
  :verbose => true, 
  :metastore => "file:cache/meta", 
  :entitystore => "file:cache/body" 

run Sinatra::Application
