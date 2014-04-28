require 'open3'

class Zorro < Sinatra::Application
  # sudo lshw -class disk -class storage -json
  get '/' do
    stdout, stderr, status = Open3.capture3 'lshw -class disk -class storage -json'
    stdout
  end
end