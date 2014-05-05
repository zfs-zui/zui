require 'disk'
require 'zfs'

class ZUI < Sinatra::Application
  get '/' do
    #puts Disk.all.inspect
    @pools = ZFS.pools
    erb :index
  end
end