require "serialport"
require "pry"
serial = SerialPort.new("/dev/tty.usbserial-A700fbj9", 19200, 8, 1, SerialPort::NONE)


# smol porgram to wryte to lcd
payload = [
  0x05, #0x00,         # length low byte, high byte
  0xa9, 0x01,         # lda #1
  0x8d, 0x01, 0x60,   # sta $6001
]

serial.putc("l")
payload.each do |byte|
  sleep(0.01)
  serial.putc(byte)
end
