require 'sinatra'
require 'json'

post '/' do
    "hello world"
end

post '/event_handler' do
  payload = JSON.parse(params[:payload])
  "Well, it worked!"
end
