# Guardfile
# More info at https://github.com/guard/guard#readme

group :server do
  guard :shotgun, :server => 'puma', :port => '8080' do
    watch %r{^(app|lib)/.*\.rb} # watch app and lib dirs
    watch 'app.rb'
    watch 'config.ru'
  end
end
