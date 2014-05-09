module ZfsHelpers
  
  def zfs_tree(root = [])
    html = ''

    root.children.each do |fs|
      html << partial(:'sidebar/fs', locals: {fs: fs})

      # Recurse through children
      html << zfs_tree(fs)
    end

    return html
  end

end