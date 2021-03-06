require 'rubygems'
require 'bundler'

# Setup load paths
Bundler.require
$: << File.expand_path('../', __FILE__)
$: << File.expand_path('../lib', __FILE__)

# Include /lib
libraries = Dir[File.expand_path('../lib/**/*.rb', __FILE__)]
libraries.each do |path_name|
  require path_name
end

# Silence a warning
I18n.config.enforce_available_locales = true


class ZUI < Sinatra::Application
  set :root,          File.join(File.dirname(__FILE__), 'app')
  set :assets,        Sprockets::Environment.new(root)
  set :assets_prefix, '/assets'
  set :digest_assets, false

  configure do
    # Use erb as template engine
    set :erb, escape_html: false

    # Setup Sprockets
    %w{javascripts stylesheets images fonts}.each do |type|
      assets.append_path File.join(root, 'assets', type)
      assets.append_path File.join(File.dirname(__FILE__), 'vendor', 'assets', type)
      # Bootstrap assets
      assets.append_path Compass::Frameworks['bootstrap'].templates_directory + "/../vendor/assets/#{type}"
    end

    # Configure Sprockets::Helpers
    Sprockets::Helpers.configure do |config|
      config.environment = assets
      config.prefix      = assets_prefix
      config.digest      = digest_assets
      config.public_path = public_folder
    end

    # Static files are served by Sprockets
    disable :static

    # Enable sessions to use flash messages across requests
    enable :sessions
    # FIXME: replace with a secret key
    set :session_secret, 'zui-key'
    # Install flash middleware, and clear stale flash entries
    use Rack::Flash, sweep: true
  end

  helpers do
    include Sprockets::Helpers
    include ActiveSupport::NumberHelper
  end
end

require_relative 'app/helpers/init'
require_relative 'app/routes/init'
