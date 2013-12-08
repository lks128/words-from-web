require './main.rb'
require 'rack/coffee'

use Rack::Coffee, { 
  :urls => '/javascripts/', 
  :output_path => '/public/javascripts' 
}

run Sinatra::Application
