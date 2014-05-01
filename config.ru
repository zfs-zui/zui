require './app'

#use Rack::Cache, verbose: false
 
map Zorro.assets_prefix do
  run Zorro.assets
end

map '/' do
  run Zorro
end
