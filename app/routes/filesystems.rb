class ZUI < Sinatra::Application

  # Show the specified filesystem,
  # represented by its full path
  get '/pools/:pool/*' do |pool, path|
    # Ignore if no path was given
    pass if path.empty?

    full_path = File.join(pool, path)
    @selected = full_path
    @fs = ZFS.new(full_path)

    erb :'filesystems/show', layout: !request.xhr?
  end

end