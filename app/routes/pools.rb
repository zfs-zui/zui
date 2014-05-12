require 'disk'
require 'zfs'

class ZUI < Sinatra::Application
  before do
    # Get the list of pools needed by the sidebar,
    # unless it's an Ajax request.
    @pools = ZFS.pools unless request.xhr?
  end

  # Render the New Pool form
  get '/pools/new' do
    @disks = Disk.all.select { |d| d.transport == 'sata' }
  	erb :'pools/new', layout: !request.xhr?
  end

  # Create a new pool
  # If an error occur, redirect to the form
  post '/pools/new' do
    name  = params[:name]
    type  = params[:type]
    disks = params[:disks]

    # Try creating the pool with the supplied parameters
    begin
      pool = ZFS::Pool.new(name)
      pool.create(type, disks)
    rescue ZFS::Error => e
      flash[:error] = e.message
      redirect back
    end

    # Pool created successfully
    flash[:ok] = "Pool '#{name}' created successfully!"
    redirect back
  end

  # List all the pools
  get '/pools/?' do
    # By default, select the first pool
    @selected = @pools.first.name if not @pools.empty?
    # FIXME: Render the correct view
    # FIXME: Check if there is a pool selected
    erb :index
  end

  # Show specified pool
  get '/pools/:name/?' do |name|
    @selected = name
    @pool = ZFS::Pool.new(name)
    erb :'pools/show', layout: !request.xhr?
  end
end