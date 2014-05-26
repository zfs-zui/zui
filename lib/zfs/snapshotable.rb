class ZFS
  module Snapshotable
    # Create a snapshot
    def snapshot!(snapname, opts={})
      raise NotFound, "Filesystem not found" if !exist?
      raise AlreadyExists, " Snapshot '#{snapname}' already exists." if ZFS("#{uid}@#{snapname}").exist?

      cmd = ZFS.zfs_path + ['snapshot']
      cmd << '-r' if opts[:children]
      cmd << "#{uid}@#{snapname}"

      out, status = Open3.capture2e(*cmd)

      if status.success? and out.empty?
        return ZFS("#{uid}@#{snapname}")
      else
        raise Error, "something went wrong: #{out}"
      end
    end

    # Get an Array of all snapshots on this filesystem.
    def snapshots(opts={})
      raise NotFound, "no such filesystem" if !exist?

      stdout, stderr = [], []
      cmd = ZFS.zfs_path + %w(list -H -r -oname -tsnapshot)
      cmd << '-d1' unless opts[:recursive]
      cmd << uid

      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success? and stderr.empty?
        stdout.lines.collect do |snap|
          ZFS(snap.chomp)
        end
      else
        raise Error, "something went wrong"
      end
    end
  end
end