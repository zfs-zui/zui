require 'pathname'
require 'date'
require 'open3'
require_relative 'snapshotable'

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
  @zfs_path   = %w(sudo zfs)
  @zpool_path = %w(sudo zpool)

  attr_reader :uid
  attr_reader :name
  attr_reader :pool
  attr_reader :path

  class Error < StandardError; end
  class ArgumentError < Error; end
  class NotFound < Error; end
  class AlreadyExists < Error; end
  class InvalidName < Error; end

  # Constructor
  def initialize(uid)
    raise ArgumentError, "The name cannot be empty." if uid.empty?
    @uid = uid
  end

  # Return the parent of the current filesystem, or nil if there is none.
  def parent
    p = Pathname(uid).parent.to_s
    if p == '.'
      nil
    else
      ZFS(p)
    end
  end

  # Returns the descendants of this filesystem
  def children(opts={})
    raise NotFound if !exist?

    cmd = ZFS.zfs_path + %w(list -H -r -oname -tfilesystem)
    cmd << '-d1' unless opts[:recursive]
    cmd << uid

    stdout, stderr, status = Open3.capture3(*cmd)
    if status.success? and stderr == ""
      stdout.lines.drop(1).collect do |fs|
        ZFS(fs.chomp)
      end
    else
      raise Error, "Something went wrong: #{stderr}"
    end
  end

  # Does the filesystem exist?
  def exist?
    cmd = ZFS.zfs_path + %w(list -H -oname) + [uid]

    out, status = Open3.capture2e(*cmd)
    return (status.success? && out == "#{uid}\n")
  end

  # Concatenate filesystems
  def +(path)
    if path.match(/^@/)
      ZFS("#{uid.to_s}#{path}")
    else
      path = Pathname(uid) + path
      ZFS(path.cleanpath.to_s)
    end
  end

  # Stringify
  def to_s
    "#<ZFS:#{uid}>"
  end

  # ZFS's are considered equal if they are the same class and name
  def ==(other)
    other.class == self.class && other.uid == self.uid
  end

  def [](key)
    cmd = ZFS.zfs_path + %w(get -ovalue -Hp) + [key.to_s, uid]

    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success? and stderr.empty? and stdout.lines.count == 1
      return stdout.chomp
    else
      raise Error, "Something went wrong: #{stderr}"
    end
  end

  def []=(key, value)
    cmd = ZFS.zfs_path + ['set', "#{key.to_s}=#{value}", uid]

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
      cmd = ZFS.zpool_path + %w(list -H -o name)
      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success? and stderr.empty?
        stdout.lines.collect do |line|
          ZFS(line.chomp)
        end
      else
        raise Error, "Something went wrong..."
      end
    end

    # Get a Hash of all mountpoints and their filesystems
    def mounts
      cmd = ZFS.zfs_path + %w(get -rHp -oname,value mountpoint)

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
          # FIXME: also takes :values. if :values is all-Integers, these are the only options.
          # if there are non-ints, then :values is a supplement
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

  def size
    used + available
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

  def initialize(uid)
    super(uid)

    if uid =~ /\//
      raise InvalidName, "A pool name cannot contain the '/' character."
    end

    @name, @pool = uid, uid
  end

  # Does the pool exist?
  def exist?
    cmd = ZFS.zpool_path + %w(list -H -oname) + [uid]

    out, status = Open3.capture2e(*cmd)
    return (status.success? && out == "#{uid}\n")
  end

  # Get pool health
  # Possible values are:
  #   online, :degraded, :faulted, :offline, :unavail, :removed
  def health
    cmd = ZFS.zpool_path + %w(list -H -o health)
    cmd << @uid
    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success? and stderr.empty? and stdout.lines.count == 1
      return stdout.chomp.downcase.to_sym
    else
      raise Error, "Something went wrong..."
    end
  end

  # Get pool status, as returned by zpool status
  def status
    cmd = ZFS.zpool_path + ['status']
    cmd << uid

    out, status = Open3.capture2e(*cmd)
    if status.success?
      return out
    else
      return "#{out}\n#{status}"
    end
  end

  # Returns the filesystems of this pool
  def children(opts={})
    if health != :online
      return []
    else
      return super(opts)
    end
  end

  # Create pool
  def create!(type, disks)
    raise AlreadyExists, "Pool '#{uid}' already exists." if exist?

    # Check disks
    disks = disks || []
    if disks.empty?
      raise ArgumentError, 'Cannot create a pool without any disks!'
    end

    cmd = ZFS.zpool_path + ['create']
    cmd << '-f' # force
    cmd << uid
    cmd << type if %w(mirror raidz1 raidz2 raidz3).include? type
    cmd << disks
    cmd.flatten!

    out, status = Open3.capture2e(*cmd)
    if status.success? and out.empty?
      return self
    elsif out.match(/exists/)
      raise AlreadyExists, "Pool '#{uid}' already exists."
    else
      raise Error, "Something went wrong: #{out}, #{status}"
    end
  end

  # Add a VDEV to an existing pool
  def add_vdev!(type, disks)
    raise NotFound, "Pool '#{uid}' does not exist." unless exist?

    # Check disks
    disks = disks || []
    if disks.empty?
      raise ArgumentError, 'Cannot extend the pool without any disks!'
    end

    cmd = ZFS.zpool_path + ['add']
    cmd << '-f' # force
    cmd << uid
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

    cmd = ZFS.zpool_path + ['destroy']
    cmd << uid

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return true
    else
      raise Error, "Something went wrong: out = #{out}"
    end
  end

end

class ZFS::Filesystem < ZFS
  include Snapshotable

  # Create a new ZFS filesystem
  def initialize(uid)
    super(uid)
    @pool, @path = *uid.split('/', 2)
    @name = @path.split('/').last
  end

  # Create filesystem
  def create!(opts={})
    raise AlreadyExists, "Filesystem '#{uid}' already exists." if exist?

    cmd = ZFS.zfs_path + ['create']
    cmd << '-p' if opts[:parents]
    cmd << '-s' if opts[:volume] and opts[:sparse]
    cmd += opts[:zfsopts].map{|el| ['-o', el]}.flatten if opts[:zfsopts]
    cmd += ['-V', opts[:volume]] if opts[:volume]
    cmd << uid

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

    cmd = ZFS.zfs_path + ['destroy']
    cmd << '-r' if opts[:children]
    cmd << uid

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return true
    else
      raise Error, "Something went wrong: out = #{out}"
    end
  end

  # Rename filesystem
  def rename!(newname, opts={})
    raise AlreadyExists if ZFS(newname).exist?

    cmd = ZFS.zfs_path + ['rename']
    cmd << '-p' if opts[:parents]
    cmd << name
    cmd << newname

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      initialize(newname)
      return self
    else
      raise Error, "something went wrong: #{out}"
    end
  end

end

class ZFS::Snapshot < ZFS
  # Snapshot constructor
  def initialize(uid)
    super(uid)

    full_path, @name = uid.split('@', 2)
    @pool, @path = *full_path.split('/', 2)
  end

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
    ZFS(uid.sub(/@.+/, ''))
  end

  # Rename snapshot
  def rename!(newname, opts={})
    newsnap = parent + "@#{newname}"
    newuid = newsnap.uid
    raise AlreadyExists, "Snapshot '#{newuid}' already exists." if newsnap.exist?

    cmd = ZFS.zfs_path + ['rename']
    cmd << '-r' if opts[:children]
    cmd << uid
    cmd << newuid

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      initialize(newuid)
      return self
    else
      raise Error, "Something went wrong: #{out}"
    end
  end

  # Clone snapshot
  def clone!(clone, opts={})
    clone = clone.uid if clone.is_a? ZFS

    raise AlreadyExists, "Clone '#{clone}' already exists." if ZFS(clone).exist?

    cmd = ZFS.zfs_path + ['clone']
    cmd << '-p' if opts[:parents]
    cmd << uid
    cmd << clone

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return ZFS(clone)
    else
      raise Error, "Something went wrong: #{out}"
    end
  end

  # Rollback snapshot
  def rollback!
    raise NotFound if !exist?

    cmd = ZFS.zfs_path + ['rollback']
    cmd << uid

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return true
    else
      raise Error, "Something went wrong: #{out}"
    end
  end

  # Destroy snapshot
  def destroy!(opts={})
    raise NotFound if !exist?

    cmd = ZFS.zfs_path + ['destroy']
    cmd << uid

    out, status = Open3.capture2e(*cmd)

    if status.success? and out.empty?
      return true
    else
      raise Error, "Something went wrong: #{out}"
    end
  end

end
