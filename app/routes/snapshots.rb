class ZUI < Sinatra::Application

  # Create a snapshot
  post '/*/snapshot' do |path|
    name = params[:name]
    halt 400, 'A name is required' if name.empty?

    fs = ZFS(path)
    halt 404, 'Filesystem does not exist' if not fs.exist?

    # FIXME: handle errors
    begin
      fs.snapshot!(name)
    rescue ZFS::Error => e
      halt 400, e.message
    end
  end

  # Rename snapshot
  put '/snapshot/*' do |path|
    "rename #{path}"
  end

  # Delete snapshot
  delete '/snapshot/*' do |path|
    snap = ZFS(path)

    # FIXME: handle errors
    snap.destroy!
  end

end