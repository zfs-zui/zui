# Guardfile
# More info at https://github.com/guard/guard#readme

group :server do
  guard :shotgun, :server => 'thin' do
    watch(/.+/) # watch *every* file in the directory
  end
end
