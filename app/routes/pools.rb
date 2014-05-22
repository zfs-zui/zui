require 'disk'
require 'zfs'

class ZUI < Sinatra::Application

  # Show a pool
  get '/:pool/' do |pool|
    @selected = pool
    # FIXME: check if it exists
    @pool = ZFS(pool)
    erb :'pools/show', layout: !request.xhr?
  end

  # Render the New Pool form
  get '/pool/new' do
    @disks = Disk.all
  	erb :'pools/new', layout: !request.xhr?
  end

  # Create a new pool
  # If an error occur, redirect to the form
  post '/pool/new' do
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

    # Success
    flash[:ok] = "Pool '#{name}' created successfully!"
    redirect back
  end

  # Render the Extend Pool form
  get '/:pool/extend' do |pool|
    @pool = ZFS::Pool.new(pool)
    halt 404, 'Pool does not exist' unless @pool.exist?

    @disks = Disk.all
    erb :'pools/extend', layout: !request.xhr?
  end

  # Extend a pool
  post '/:pool/extend' do |pool| 
    pool = ZFS::Pool.new(pool)
    halt 404, 'Pool does not exist' unless pool.exist?

    type  = params[:type]
    disks = params[:disks]

    # Try expanding the pool with the supplied parameters
    begin
      pool.add_vdev(type, disks)
    rescue ZFS::Error => e
      flash[:error] = e.message
      redirect back
    end

    # Success
    flash[:ok] = "Pool '#{name}' successfully extended!"
    redirect back
  end

  # Destroy a pool
  delete '/:pool/' do |pool|
    pool = ZFS::Pool.new(pool)
    halt 404, 'Pool does not exist' unless pool.exist?

    begin
      pool.destroy!
    rescue ZFS::Error => e
      # FIXME: do something
      puts e.message
      halt 500
    end
    redirect to('/')
  end
  
end