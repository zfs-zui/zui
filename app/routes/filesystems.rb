class ZUI < Sinatra::Application

  # Show the specified filesystem,
  # represented by its full path
  get '/pools/:pool/*/' do |pool, path|
    # Ignore if no path was given
    pass if path.empty?

    full_path = File.join(pool, path)
    @selected = full_path
    @fs = ZFS.new(full_path)

    erb :'filesystems/show', layout: !request.xhr?
  end

  # Render the New Filesystem form
  get '/fs/new' do
    # FIXME: hack to bypass the before filter
    @pools = ZFS.pools if request.xhr?

    erb :'filesystems/new', layout: !request.xhr?
  end

  # Create a new filesystem
  post '/fs/new' do
    name = params[:name]
    path = params[:path]

    # Validate fields
    if name.empty? || path.empty?
      flash[:error] = 'The name cannot be empty.'
      redirect back
    end

    # Try creating the filesystem
    begin
      fs = ZFS(File.join(path, name))
      fs.create({ parents: true })
    rescue ZFS::Error => e
      flash[:error] = e.message
      redirect back
    end

    # Filesystem created successfully
    flash[:ok] = "Filesystem '#{fs.name}' created successfully!"
    redirect back
  end

  # Destroy a filesystem
  delete '/pools/:pool/*' do |pool, path|
    fs = ZFS(File.join(pool, path))
    if not fs.exist?
      halt 404, 'Filesystem does not exist'
    end

    begin
      fs.destroy!
    rescue ZFS::Error => e
      # FIXME: handle errors
      puts e.message
    end
    redirect to('/')
  end

end