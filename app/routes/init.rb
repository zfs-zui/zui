require_relative 'home'
require_relative 'pools'
require_relative 'filesystems'
require_relative 'snapshots'

class ZUI < Sinatra::Application
  before do
    # Get the list of pools needed by the sidebar,
    # unless it's an Ajax request.
    @pools = ZFS.pools unless request.xhr?
  end
end
