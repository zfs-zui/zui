require 'disk'

class Zorro < Sinatra::Application
  get '/' do
    puts Disk.all.inspect
    erb :index
  end
end