require 'pathname'
require 'date'
require 'open3'
require 'snapshot.rb'

# Get the correct ZFS object depending on the path
def ZFS(path)
  return path if path.is_a? ZFS

  path = Pathname(path).cleanpath.to_s

  if path.match(/^\//)
    ZFS.mounts[path]
  elsif path.match('@')
    ZFS::Snapshot.new(path)
  elsif !path.match('/')
    ZFS::Pool.new(path)
  else
    ZFS::Filesystem.new(path)
  end
end

# Pathname-inspired class to handle ZFS filesystems/snapshots/volumes
class ZFS
  @zfs_path   = %w(sudo zfs) # zfs
  @zpool_path = %w(sudo zpool) # zpool

  attr_reader :name
  attr_reader :pool
  attr_reader :path

  class Error < StandardError; end
  class ArgumentError < Error; end
  class NotFound < Error; end
  class AlreadyExists < Error; end
  class InvalidName < Error; end

  # Create a new ZFS object (_not_ filesystem)
  def initialize(name)
    if name.length < 1
      raise ArgumentError, "The name cannot be empty."
    end
    @name, @pool, @path = name, *name.split('/', 2)
  end

  # Return the path including the pool
  def full_path
    File.join(@pool, @path)
  end

  # Return the parent of the current filesystem, or nil if there is none.
  def parent
    p = Pathname(name).parent.to_s
    if p == '.'
      nil
    else
      ZFS(p)
    end
  end

  # Returns the descendants of this filesystem
  def children(opts={})
    raise NotFound if !exist?

    cmd = [ZFS.zfs_path].flatten + %w(list -H -r -oname -tfilesystem)
    cmd << '-d1' unless opts[:recursive]
    cmd << name

    stdout, stderr, status = Open3.capture3(*cmd)
    if status.success? and stderr == ""
      stdout.lines.drop(1).collect do |fs|
        ZFS(fs.chomp)
      end
    else
      raise Error, "Something went wrong..."
    end
  end

  # Does the filesystem exist?
  def exist?
    cmd = [ZFS.zfs_path].flatten + %w(list -H -oname) + [name]

    out, status = Open3.capture2e(*cmd)
    if status.success? and out == "#{name}\n"
      true
    else
      false
    end
  end

  # Create filesystem
  def create(opts={})
    #return nil if exist?
    raise AlreadyExists, "Filesystem '#{name}' already exists." if exist?

    cmd = [ZFS.zfs_path].flatten + ['create']
    cmd << '-p' if opts[:parents]
    cmd << '-s' if opts[:volume] and opts[:sparse]
    cmd += opts[:zfsopts].map{|el| ['-o', el]}.flatten if opts[:zfsopts]
    cmd += ['-V', opts[:volume]] if opts[:volume]
    cmd << name

    out, status = Open3.capture2e(*cmd)
    if status.success? and out.empty?
      return self
    elsif out.match(/dataset already exists\n$/)
      nil
    else
      raise Error, "Something went wrong: #{out}, #{status}"
    end
  end

  # Destroy filesystem
  def destroy!(opts={})
    raise NotFound if !exist?

    cmd = [ZFS.zfs_path].flatten + ['destroy']
    cmd << '-r' if opts[:children]
    cmd << name

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return true
    else
      raise Error, "Something went wrong: out = #{out}"
    end
  end

  # Stringify
  def to_s
    "#<ZFS:#{name}>"
  end

  # ZFS's are considered equal if they are the same class and name
  def ==(other)
    other.class == self.class && other.name == self.name
  end

  def [](key)
    cmd = [ZFS.zfs_path].flatten + %w(get -ovalue -Hp) + [key.to_s, name]

    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success? and stderr.empty? and stdout.lines.count == 1
      return stdout.chomp
    else
      raise Error, "Something went wrong..."
    end
  end

  def []=(key, value)
    cmd = [ZFS.zfs_path].flatten + ['set', "#{key.to_s}=#{value}", name]

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return value
    else
      raise Error, "Something went wrong: #{out}"
    end
  end

  class << self
    attr_accessor :zfs_path
    attr_accessor :zpool_path

    # Get an Array of all pools
    def pools
      cmd = [ZFS.zpool_path].flatten + %w(list -H -o name)
      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success? and stderr.empty?
        stdout.lines.collect do |line|
          #values = line.split("\t")
          #puts values
          #name   = values[0]
          #health = values[1]
          #pool = ZFS::Pool.new(name.chomp)
          #pool.health = health.chomp.downcase.to_sym
          #pool
          ZFS(line.chomp)
        end
      else
        raise Error, "Something went wrong..."
      end
    end

    # Get a Hash of all mountpoints and their filesystems
    def mounts
      cmd = [ZFS.zfs_path].flatten + %w(get -rHp -oname,value mountpoint)

      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success? and stderr.empty?
        mounts = stdout.lines.collect do |line|
          fs, path = line.chomp.split(/\t/, 2)
          [path, ZFS(fs)]
        end
        Hash[mounts]
      else
        raise Error, "Something went wrong..."
      end
    end

    # Define an attribute
    def property(name, opts={})

      case opts[:type]
        when :size, :integer
          # FIXME: also takes :values. if :values is all-Integers, these are the only options. if there are non-ints, then :values is a supplement

          define_method name do
            Integer(self[name])
          end
          define_method "#{name}=" do |value|
            self[name] = value.to_s
          end if opts[:edit]

        when :boolean
          # FIXME: booleans can take extra values, so there are on/true, off/false, plus what amounts to an enum
          # FIXME: if options[:values] is defined, also create a 'name' method, since 'name?' might not ring true
          # FIXME: replace '_' by '-' in opts[:values]
          define_method "#{name}?" do
            values = %w(on yes true)
            values += opts[:values].map { |sym| sym.to_s } if opts[:values]
            #self[name] == 'on'
            values.include? self[name]
          end
          define_method "#{name}=" do |value|
            self[name] = value ? 'on' : 'off'
          end if opts[:edit]

        when :enum
          define_method name do
            sym = (self[name] || "").gsub('-', '_').to_sym
            if opts[:values].grep(sym)
              return sym
            else
              raise "#{name} has value #{sym}, which is not in enum-list"
            end
          end
          define_method "#{name}=" do |value|
            self[name] = value.to_s.gsub('_', '-')
          end if opts[:edit]

        when :snapshot
          define_method name do
            val = self[name]
            if val.nil? or val == '-'
              nil
            else
              ZFS(val)
            end
          end

        when :float
          define_method name do
            Float(self[name])
          end
          define_method "#{name}=" do |value|
            self[name] = value
          end if opts[:edit]

        when :string
          define_method name do
            self[name]
          end
          define_method "#{name}=" do |value|
            self[name] = value
          end if opts[:edit]

        when :date
          define_method name do
            DateTime.strptime(self[name], '%s')
          end

        when :pathname
          define_method name do
            Pathname(self[name])
          end
          define_method "#{name}=" do |value|
            self[name] = value.to_s
          end if opts[:edit]

        else
          puts "Unknown type '#{opts[:type]}'"
      end
    end
    private :property
  end

  property :available,            type: :size
  property :compressratio,        type: :float
  property :creation,             type: :date
  property :defer_destroy,        type: :boolean
  property :mounted,              type: :boolean
  property :origin,               type: :snapshot
  property :refcompressratio,     type: :float
  property :referenced,           type: :size
  property :type,                 type: :enum, values: [:filesystem, :snapshot, :volume]
  property :used,                 type: :size
  property :usedbychildren,       type: :size
  property :usedbydataset,        type: :size
  property :usedbyrefreservation, type: :size
  property :usedbysnapshots,      type: :size
  property :userrefs,             type: :integer

  property :aclinherit,           type: :enum,    edit: true, inherit: true, values: [:discard, :noallow, :restricted, :passthrough, :passthrough_x]
  property :atime,                type: :boolean, edit: true, inherit: true
  property :canmount,             type: :boolean, edit: true,                values: [:noauto]
  property :checksum,             type: :boolean, edit: true, inherit: true, values: [:fletcher2, :fletcher4, :sha256]
  property :compression,          type: :boolean, edit: true, inherit: true, values: [:lz4, :lzjb, :gzip, :gzip_1, :gzip_2, :gzip_3, :gzip_4, :gzip_5, :gzip_6, :gzip_7, :gzip_8, :gzip_9, :zle]
  property :copies,               type: :integer, edit: true, inherit: true, values: [1, 2, 3]
  property :dedup,                type: :boolean, edit: true, inherit: true, values: [:verify, :sha256, 'sha256,verify']
  property :devices,              type: :boolean, edit: true, inherit: true
  property :exec,                 type: :boolean, edit: true, inherit: true
  property :logbias,              type: :enum,    edit: true, inherit: true, values: [:latency, :throughput]
  property :mlslabel,             type: :string,  edit: true, inherit: true
  property :mountpoint,           type: :pathname,edit: true, inherit: true
  property :nbmand,               type: :boolean, edit: true, inherit: true
  property :primarycache,         type: :enum,    edit: true, inherit: true, values: [:all, :none, :metadata]
  property :quota,                type: :size,    edit: true,                values: [:none]
  property :readonly,             type: :boolean, edit: true, inherit: true
  property :recordsize,           type: :integer, edit: true, inherit: true, values: [512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072]
  property :refquota,             type: :size,    edit: true,                values: [:none]
  property :refreservation,       type: :size,    edit: true,                values: [:none]
  property :reservation,          type: :size,    edit: true,                values: [:none]
  property :secondarycache,       type: :enum,    edit: true, inherit: true, values: [:all, :none, :metadata]
  property :setuid,               type: :boolean, edit: true, inherit: true
  property :sharenfs,             type: :boolean, edit: true, inherit: true # FIXME: also takes 'share(1M) options'
  property :sharesmb,             type: :boolean, edit: true, inherit: true # FIXME: also takes 'sharemgr(1M) options'
  property :snapdir,              type: :enum,    edit: true, inherit: true, values: [:hidden, :visible]
  property :sync,                 type: :enum,    edit: true, inherit: true, values: [:standard, :always, :disabled]
  property :version,              type: :integer, edit: true,                values: [1, 2, 3, 4, :current]
  property :vscan,                type: :boolean, edit: true, inherit: true
  property :xattr,                type: :boolean, edit: true, inherit: true
  property :zoned,                type: :boolean, edit: true, inherit: true
  property :jailed,               type: :boolean, edit: true, inherit: true
  property :volsize,              type: :size,    edit: true

  property :casesensitivity,      type: :enum,    create_only: true, values: [:sensitive, :insensitive, :mixed]
  property :normalization,        type: :enum,    create_only: true, values: [:none, :formC, :formD, :formKC, :formKD]
  property :utf8only,             type: :boolean, create_only: true
  property :volblocksize,         type: :integer, create_only: true, values: [512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072]

end

class ZFS::Pool < ZFS
  include Snapshotable

  attr_accessor :health

  # Override constructor for better error handling
  def initialize(name)
    if name =~ /\//
      raise InvalidName, "A pool name cannot contain the '/' character."
    end
    super(name)
  end

  # Overriden, since @path is nil for a pool
  def full_path
    @pool
  end

  # Create pool
  def create(type, disks)
    raise AlreadyExists, "Pool '#{name}' already exists." if exist?

    # Check disks
    disks = disks || []
    if disks.empty?
      raise ArgumentError, 'Cannot create a pool without any disks!'
    end

    cmd = [ZFS.zpool_path].flatten + ['create']
    cmd << '-f' # force
    cmd << name
    cmd << type if %w(mirror raidz1 raidz2 raidz3).include? type
    cmd << disks
    cmd.flatten!

    out, status = Open3.capture2e(*cmd)
    if status.success? and out.empty?
      return self
    elsif out.match(/exists/)
      raise AlreadyExists, "Pool '#{name}' already exists."
    else
      raise Error, "Something went wrong: #{out}, #{status}"
    end
  end

  # Add a VDEV to an existing pool
  def add_vdev(type, disks)
    raise NotFound, "Pool '#{name}' does not exist." unless exist?

    # Check disks
    disks = disks || []
    if disks.empty?
      raise ArgumentError, 'Cannot extend the pool without any disks!'
    end

    cmd = [ZFS.zpool_path].flatten + ['add']
    cmd << '-f' # force
    cmd << name
    cmd << type if %w(mirror raidz1 raidz2 raidz3).include? type
    cmd << disks
    cmd.flatten!

    out, status = Open3.capture2e(*cmd)
    if status.success? and out.empty?
      return self
    else
      raise Error, "Something went wrong: #{out}, #{status}"
    end
  end

  # Destroy pool
  def destroy!
    raise NotFound if !exist?

    cmd = [ZFS.zpool_path].flatten + ['destroy']
    cmd << name

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return true
    else
      raise Error, "Something went wrong: out = #{out}"
    end
  end

  def status
    cmd = [ZFS.zpool_path].flatten + ['status']
    cmd << name

    out, status = Open3.capture2e(*cmd)
    if status.success?
      return out
    else
      return "#{out}\n#{status}"
    end
  end
end

class ZFS::Snapshot < ZFS
  def properties_modifiable?
    false
  end

  # Return sub-filesystem
  def +(path)
    raise InvalidName if path.match(/@/)

    parent + path + name.sub(/^.+@/, '@')
  end

  # Just remove the snapshot name
  def parent
    ZFS(name.sub(/@.+/, ''))
  end

  # Rename snapshot
  def rename!(newname, opts={})
    raise AlreadyExists if (parent + "@#{newname}").exist?

    newname = (parent + "@#{newname}").name

    cmd = [ZFS.zfs_path].flatten + ['rename']
    cmd << '-r' if opts[:children]
    cmd << name
    cmd << newname

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      initialize(newname)
      return self
    else
      raise Exception, "something went wrong"
    end
  end

  # Clone snapshot
  def clone!(clone, opts={})
    clone = clone.name if clone.is_a? ZFS

    raise AlreadyExists if ZFS(clone).exist?

    cmd = [ZFS.zfs_path].flatten + ['clone']
    cmd << '-p' if opts[:parents]
    cmd << name
    cmd << clone

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return ZFS(clone)
    else
      raise Exception, "something went wrong: out = #{out}"
    end
  end

  # Send snapshot to another filesystem
  def send_to(dest, opts={})
    incr_snap = nil
    dest = ZFS(dest)

    if opts[:incremental] and opts[:intermediary]
      raise ArgumentError, "can't specify both :incremental and :intermediary"
    end

    incr_snap = opts[:incremental] || opts[:intermediary]
    if incr_snap
      if incr_snap.is_a? String and incr_snap.match(/^@/)
        incr_snap = self.parent + incr_snap
      else
        incr_snap = ZFS(incr_snap)
        raise ArgumentError, "incremental snapshot must be in the same filesystem as #{self}" if incr_snap.parent != self.parent
      end

      snapname = incr_snap.name.sub(/^.+@/, '@')

      raise NotFound, "destination must already exist when receiving incremental stream" unless dest.exist?
      raise NotFound, "snapshot #{snapname} must exist at #{self.parent}" if self.parent.snapshots.grep(incr_snap).empty?
      raise NotFound, "snapshot #{snapname} must exist at #{dest}" if dest.snapshots.grep(dest + snapname).empty?
    elsif opts[:use_sent_name]
      raise NotFound, "destination must already exist when using sent name" unless dest.exist?
    elsif dest.exist?
      raise AlreadyExists, "destination must not exist when receiving full stream"
    end

    dest = dest.name if dest.is_a? ZFS
    incr_snap = incr_snap.name if incr_snap.is_a? ZFS

    send_opts = ZFS.zfs_path.flatten + ['send']
    send_opts.concat ['-i', incr_snap] if opts[:incremental]
    send_opts.concat ['-I', incr_snap] if opts[:intermediary]
    send_opts << '-R' if opts[:replication]
    send_opts << name

    receive_opts = ZFS.zfs_path.flatten + ['receive']
    receive_opts << '-d' if opts[:use_sent_name]
    receive_opts << dest

    Open3.popen3(*receive_opts) do |rstdin, rstdout, rstderr, rthr|
      Open3.popen3(*send_opts) do |sstdin, sstdout, sstderr, sthr|
        while !sstdout.eof?
          rstdin.write(sstdout.read(16384))
        end
        raise "stink" unless sstderr.read == ''
      end
    end
  end
end


class ZFS::Filesystem < ZFS
  include Snapshotable

  # Return sub-filesystem
  def +(path)
    if path.match(/^@/)
      ZFS("#{name.to_s}#{path}")
    else
      path = Pathname(name) + path
      ZFS(path.cleanpath.to_s)
    end
  end

  # Rename filesystem
  def rename!(newname, opts={})
    raise AlreadyExists if ZFS(newname).exist?

    cmd = [ZFS.zfs_path].flatten + ['rename']
    cmd << '-p' if opts[:parents]
    cmd << name
    cmd << newname

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      initialize(newname)
      return self
    else
      raise Exception, "something went wrong: out = #{out}"
    end
  end

  # Promote this filesystem.
  def promote!
    raise NotFound, "filesystem is not a clone" if self.origin.nil?

    cmd = [ZFS.zfs_path].flatten + ['promote', name]

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return self
    else
      raise Exception, "something went wrong: out = #{out}"
    end
  end
end
