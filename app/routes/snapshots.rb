class ZUI < Sinatra::Application

  # Create a snapshot
  post '/*/snapshot' do |path|
    name = params[:name]
    halt 400, 'A name is required' if name.empty?

    fs = ZFS(path)
    halt 404, 'Filesystem does not exist' if not fs.exist?

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

  # Delete one or multiple snapshots
  delete '/snapshot' do
    snapshots = params[:snapshots]
    snapshots.each do |snap|
      begin
        ZFS(snap).destroy!
      rescue ZFS::Error => e
        halt 400, e.message
      end
    end
  end

end