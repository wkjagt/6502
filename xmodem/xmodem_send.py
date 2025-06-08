import serial
import time
from xmodem import XMODEM
import pdb

ser = serial.Serial(
            port="/dev/tty.usbserial-A700fbj9",
            baudrate=19200,
            bytesize=serial.EIGHTBITS,
            stopbits=serial.STOPBITS_ONE,
            parity=serial.PARITY_NONE
        )
def getc(size, timeout=1):
    received = ser.read(size)
    print(received)
    return received or None

def putc(data, timeout=1):
    for byte in data:
        while not ser.getCTS():
            pass
        time.sleep(0.0005)
        ser.write(bytes([byte]))
    print("Sent packet")

modem = XMODEM(getc, putc)
stream = open('/Users/willemvanderjagt/code/github.com/wkjagt/6502/tmp/out.bin', 'rb')
print("Waiting for NAK")
modem.send(stream)
