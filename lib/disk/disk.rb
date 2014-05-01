require 'json'
require 'open3'

BIN_DIR = File.join(File.dirname(__FILE__), 'bin')
LSBLK_BIN = File.join(BIN_DIR, 'lsblk')

class Disk
  attr_accessor :name

  def self.all
    list = []

    # We use a modified version of lsblk,
    # which can output JSON.
    cmd = "#{LSBLK_BIN} -j -b"
    stdout, stderr, status = Open3.capture3(cmd)
    if not status.success?
      puts stderr
      return nil
    end

    JSON.parse(stdout, symbolize_names: true).each do |block|
      if block[:type] == 'disk'
        disk = Disk.new(block[:name])
        list << disk
      end
    end
    
    list
  end

  def self.unused
    all_disks = self.all
    all_disks
  end

  def initialize(name)
    @name = name
  end

  def to_s
    "<Disk #{@name}>"
  end
end
