require 'json'
require 'open3'

BIN_DIR = File.join(File.dirname(__FILE__), 'bin')
LSBLK_BIN = File.join(BIN_DIR, 'lsblk')

class Disk
  attr_accessor :name
  attr_accessor :size
  attr_accessor :model
  attr_accessor :transport
  attr_accessor :partitioned

  def self.all
    list = []

    # We use a patched version of lsblk,
    # which can output JSON.
    cmd = "sudo #{LSBLK_BIN} -j -b -o NAME,TYPE,SIZE,MODEL,PARTLABEL,FSTYPE,MOUNTPOINT,TRAN"
    stdout, stderr, status = Open3.capture3(cmd)
    if not status.success?
      puts stderr
      return nil
    end

    JSON.parse(stdout, symbolize_names: true).each do |block|
      if block[:type] == 'disk'
        disk           = Disk.new(block[:name].strip)
        disk.size      = block[:size].to_i
        disk.model     = block[:model].strip
        disk.transport = block[:tran]
        disk.partitioned = false

        parts = block[:parts] || []
        parts.each do |part|
          if part[:fstype].length > 0 || part[:partlabel].length > 0
            disk.partitioned = true 
          end
        end

        list << disk
      end
    end
    
    list
  end

  def initialize(name)
    @name = name
  end

  def to_s
    "<Disk #{@name}>"
  end

  def partitioned?
    partitioned
  end
end

