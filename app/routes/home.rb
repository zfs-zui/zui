require 'disk'
require 'zfs'

class ZUI < Sinatra::Application
  get '/' do
    redirect to('/pools')
  end
end