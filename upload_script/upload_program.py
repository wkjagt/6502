import pdb
import os
import serial
from itertools import izip_longest
import time
import inspect

class Uploader:
    NOP = 0xea                   # no-op instruction byte to fill left over space with
    SOH = chr(0x01)              # start of header
    EOT = chr(0x04)              # end of transmission
    WRITE_PAUSE = 0.0005         # pause between each byte
    PACKET_SIZE = 128

    def __init__(self, serial_device_name, program_path):
        self.path = program_path
        self.packets = self.load_packets()
        self.serial_port = self.open_serial_port(serial_device_name)
        self.test_file = open ("test_file", "ab")

    def load_packets(self):
        program_bytes = self.program_bytes()
        return self.add_padding(program_bytes)

    def add_padding(self, program_bytes):
        unpadded = [iter(program_bytes)] * self.PACKET_SIZE
        return izip_longest(fillvalue=self.NOP, *unpadded)


    def open_serial_port(self, serial_device_name):
        return serial.Serial(
            port=serial_device_name,
            baudrate=19200,
            bytesize=serial.EIGHTBITS,
            stopbits=serial.STOPBITS_ONE,
            parity=serial.PARITY_NONE
        )
    
    def upload(self):
        self.write_byte("l")

        for packet in self.packets:
            self.upload_packet(packet)

        self.write_byte(self.EOT)
        self.serial_port.close()
        
    def upload_packet(self, packet):
        self.write_byte(self.SOH)
        for byte in packet:
            self.write_byte(chr(byte))

    def write_byte(self, byte):
        time.sleep(self.WRITE_PAUSE)
        self.serial_port.write(byte)
    
    def program_bytes(self):
        bytes = bytearray()
        with open(self.path, "r") as f:
            while True:
                byte = f.read(1)
                if byte:
                    bytes.append(byte)
                else:
                    break
        return bytes

uploader = Uploader("/dev/tty.usbserial-A700fbj9", os.environ["ROM"])
uploader.upload()

