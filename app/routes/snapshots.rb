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
  put '/snapshot/*' do |snapshot|
    newname = params[:newname]
    snap = ZFS(snapshot)

    begin
      snap.rename!(newname)
    rescue ZFS::Error => e
      halt 400, e.message
    end
  end

  # Rollback snapshot
  post '/snapshot/*/rollback' do |snapshot|
    snap = ZFS(snapshot)

    begin
      snap.rollback!
    rescue ZFS::Error => e
      halt 400, e.message
    end
  end

  # Clone snapshot
  post '/snapshot/*/clone' do |snapshot|
    name = params[:name]
    location = params[:location]
    # Check inputs
    if name.empty? or location.empty?
      halt 400, "The clone name and its location cannot be empty." 
    end

    snap = ZFS(snapshot)
    begin
      snap.clone!(File.join(location, name))
    rescue ZFS::Error => e
      halt 400, e.message
    end
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