require_relative 'pools'
require_relative 'filesystems'
require_relative 'snapshots'

class ZUI < Sinatra::Application
  get '/' do
    redirect to('/pools')
  end
end