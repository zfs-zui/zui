class ZUI < Sinatra::Application

  # Create a snapshot
  post '/pools/*/snapshot' do |path|
    name = params[:name]
    halt 400, 'A name is required' if name.empty?

    fs = ZFS(path)
    halt 404, 'Filesystem does not exist' if not fs.exist?

    # FIXME: handle errors
    fs.snapshot!(name)
    
    redirect to('/pools/'+path+'/')
  end

end