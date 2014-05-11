require 'disk'
require 'zfs'

class ZUI < Sinatra::Application
  # List all the pools
  get '/pools' do
    @pools = ZFS.pools
    erb :index
  end

  # Render the New Pool form
  get '/pools/new' do
    @pools = ZFS.pools
  	erb :'pools/new'
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
end