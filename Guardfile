# Guardfile
# More info at https://github.com/guard/guard#readme

group :server do
  guard :shotgun, :server => 'puma' do
    watch(/.+/) # watch *every* file in the directory
  end
end
