require 'bundler/inline'

gemfile do
  source "https://rubygems.org"
  git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }
  
  gem "serialport"
  gem "pry"
  gem "progress_bar"
  gem "colorize"
end

ROM = ENV["ROM"]

begin
  serial = SerialPort.new("/dev/tty.usbserial-A700fbj9", 19200, 8, 1, SerialPort::NONE)
rescue Errno::ENOENT
  puts "\nSerial not plugged in\n\n"
  exit(1)
end

class ProgressBar
  def render_rate
    "[%#{max_width + 3}.2fB/s]" % rate
  end
end

puts 
puts ("Uploading " + ROM.colorize(:light_blue).bold + " to 6502 computer").underline
puts

serial.putc("l")

File.open(ROM) do |file|
  packet_bytes = file.read.bytes
  if packet_bytes.size < 128
    packet_bytes += [0] * (128 - packet_bytes.size)
  end

  bar = ProgressBar.new(packet_bytes.size)

  packet_bytes.each do |byte|
    sleep(0.01)
    serial.putc(byte)
    bar.increment!
  end
end