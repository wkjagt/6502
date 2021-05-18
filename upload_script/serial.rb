require 'bundler/inline'

gemfile do
  source "https://rubygems.org"
  git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }
  
  gem "serialport"
  gem "pry"
  gem "progress_bar"
  gem "colorize"
end

class ProgressBar
  def render_rate
    "[%#{max_width + 3}.2fB/s]" % rate
  end
end

class Uploader
  NOP = 0xea              # no-op instruction byte to fill left over space with
  SOH = 0x01              # start of header
  EOT = 0x04              # end of transmission
  WRITE_PAUSE = 0.0005    # pause between each byte
  PACKET_SIZE = 128

  def initialize(serial:, path:)
    @path = path
    @packets = load_packets(path)
    @serial_port = open_serial_port(serial)
    @progress_bar = ProgressBar.new(calculate_size)
  end

  def upload
    puts ("Uploading " + @path.colorize(:light_blue).bold + " to 6502 computer").underline
    
    write_byte("l")

    @packets.each { |packet| upload_packet(packet) }
    write_byte(EOT)
  end

  private

  def upload_packet(packet)
    write_byte(SOH)

    packet.each { |byte| write_byte(byte) }
  end

  def write_byte(byte)
    sleep(WRITE_PAUSE)
    @serial_port.putc(byte)
    @progress_bar.increment!
  end

  def load_packets(path)
    program_bytes(path).each_slice(PACKET_SIZE).map do |unpadded|
      pad(unpadded)
    end
  end

  def pad(packet)
    return packet if packet.size == PACKET_SIZE
    packet + [NOP] * (128 - packet.size)
  end

  def program_bytes(path)
    File.open(path) { |file| file.read.bytes }
  rescue
    raise "ROM not found: #{@path}"
  end

  def open_serial_port(serial)
    SerialPort.new(serial, 19200, 8, 1, SerialPort::NONE)
  rescue Errno::ENOENT
    raise "Serial device not found"
  end

  def calculate_size
    @packets.size * 129 + 1
  end
end

begin
  uploader = Uploader.new(serial: "/dev/tty.usbserial-A700fbj9", path: ENV["ROM"])
  uploader.upload
rescue => error
  puts "\n#{error.to_s}\n".colorize(:red).bold
end
