class ZFS
  module Snapshotable
    # Create a snapshot
    def snapshot!(snapname, opts={})
      raise NotFound, "no such filesystem" if !exist?
      raise AlreadyExists, "#{snapname} exists" if ZFS("#{name}@#{snapname}").exist?

      cmd = [ZFS.zfs_path].flatten + ['snapshot']
      cmd << '-r' if opts[:children]
      cmd << "#{name}@#{snapname}"

      out, status = Open3.capture2e(*cmd)

      if status.success? and out.empty?
        return ZFS("#{name}@#{snapname}")
      else
        raise Exception, "something went wrong: #{out}"
      end
    end

    # Get an Array of all snapshots on this filesystem.
    def snapshots(opts={})
      raise NotFound, "no such filesystem" if !exist?

      stdout, stderr = [], []
      cmd = [ZFS.zfs_path].flatten + %w(list -H -r -oname -tsnapshot)
      cmd << '-d1' unless opts[:recursive]
      cmd << name

      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success? and stderr.empty?
        stdout.lines.collect do |snap|
          ZFS(snap.chomp)
        end
      else
        raise Exception, "something went wrong"
      end
    end
  end
end