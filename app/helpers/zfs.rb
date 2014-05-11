module ZFS::Helpers
  
  def zfs_tree(root = [])
    html = ''

    root.children({recursive: true}).each do |fs|
      html << partial(:'sidebar/fs', locals: {fs: fs})

      # Recurse through children
      #html << zfs_tree(fs)
    end

    return html
  end

  def percentage_used(fs)
    total = fs.used.to_f + fs.available.to_f
    ((fs.used.to_f / total) * 100.0).ceil
  end

end