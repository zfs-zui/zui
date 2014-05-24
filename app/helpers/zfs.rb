module ZFS::Helpers

  # Return the percentage used by the specified ZFS filesystem
  # 	fs: ZFS object
  def percentage_used(fs)
    used = fs.used.to_f
    total = fs.size.to_f
    ((used / total) * 100.0).ceil
  end

end