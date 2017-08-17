require 'sinatra'
require_relative '../lib/rufo'
require 'rouge'

get '/:file' do
  erb :index, locals: { source: File.read(params['file']) }
end
