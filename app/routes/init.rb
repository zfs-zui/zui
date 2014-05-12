require_relative 'pools'
require_relative 'filesystems'

class ZUI < Sinatra::Application
  get '/' do
    redirect to('/pools')
  end
end