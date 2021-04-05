code = bytearray([
  # set data direction
  0xa9, 0xff,       # lda #$ff
  0x8d, 0x02, 0x60, # sta $6002
  
  # load $55 into the output pins for port B
  0xa9, 0x55,       # lda #$55
  0x8d, 0x00, 0x60, # sta $6000

  # load $aa into the output pins for port B
  0xa9, 0xaa,       # lda #$aa
  0x8d, 0x00, 0x60, # sta $6000

  0x4c, 0x05, 0x80  # jmp $9005
])


rom = code +bytearray([0xea] * (32768 - len(code)))


rom[0x7ffc] = 0x00 # in the rom this is 7ffc, but the PCU sees it fffc (msb is high) 
rom[0x7ffd] = 0x80


with open("rom.bin", "wb") as out_file:
  out_file.write(rom)
