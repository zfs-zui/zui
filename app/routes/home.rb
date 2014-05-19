class ZUI < Sinatra::Application
  get '/' do
    erb :index
  end
end