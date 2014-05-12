module ZFS::Helpers
  
  def zfs_tree(pool, selected='')
    html = ''

    pool.children({recursive: true}).each do |fs|
      html << partial(:'sidebar/filesystem', locals: {fs: fs, selected: selected})
    end

    return html
  end

  def percentage_used(fs)
    total = fs.used.to_f + fs.available.to_f
    ((fs.used.to_f / total) * 100.0).ceil
  end

end