class ZUI < Sinatra::Application
  # Home page
  get '/' do
    erb :index, layout: !request.xhr?
  end
end