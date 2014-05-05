require './app'

#use Rack::Cache, verbose: false
 
map ZUI.assets_prefix do
  run ZUI.assets
end

map '/' do
  run ZUI
end
