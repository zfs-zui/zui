class ZUI < Sinatra::Application
  # Home page
  get '/' do
    erb :index
  end
end