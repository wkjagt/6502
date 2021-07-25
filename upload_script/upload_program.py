import pdb
import os
import serial
from itertools import zip_longest
import time

class Uploader:
    NOP = 0xea                   # no-op instruction byte to fill left over space with
    SOH = 0x01                   # start of header
    EOT = 0x04                   # end of transmission
    WRITE_PAUSE = 0.0005         # pause between each byte
    PACKET_SIZE = 128

    def __init__(self, serial_device_name, program_path):
        self.path = program_path
        self.packets = self.load_packets()
        self.serial_port = self.open_serial_port(serial_device_name)

    def load_packets(self):
        program_bytes = self.program_bytes()
        return self.add_padding(program_bytes)

    def add_padding(self, program_bytes):
        packets = [program_bytes[i:i + self.PACKET_SIZE] for i in range(0, len(program_bytes), self.PACKET_SIZE)]
        
        last_packet = packets[-1]
        if len(last_packet) < self.PACKET_SIZE:
            packets[-1] = last_packet + [self.NOP] * (self.PACKET_SIZE - len(last_packet))
        
        return packets

    def open_serial_port(self, serial_device_name):
        return serial.Serial(
            port=serial_device_name,
            baudrate=19200,
            bytesize=serial.EIGHTBITS,
            stopbits=serial.STOPBITS_ONE,
            parity=serial.PARITY_NONE
        )
    
    def upload(self):
        self.write_byte(ord('l'))

        for packet in self.packets:
            self.upload_packet(packet)

        self.write_byte(self.EOT)
        self.serial_port.close()
        
    def upload_packet(self, packet):
        self.write_byte(self.SOH)
        for byte in packet:
            self.write_byte(byte)

    def write_byte(self, byte):
        time.sleep(self.WRITE_PAUSE)
        self.serial_port.write(bytes([byte]))
    
    def program_bytes(self):
        with open(self.path, "rb") as f:
            return list(bytearray(f.read()))

uploader = Uploader("/dev/tty.usbserial-A700fbj9", os.environ["ROM"])
uploader.upload()

