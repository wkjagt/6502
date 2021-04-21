# all: bootloader.rom

# clean:
# 	rm -f *.lst *.map *.o *.rom

# %.o: %.s
# 	ca65 -o $@ $<

# %.rom: %.o bootloader.cfg
# 	ld65 -C bootloader.cfg -o $@ $<

# .PHONY: all clean


link: bootloader.o io.o lcd.o serial.o
	ld65 -t none bootloader.o io.o lcd.o serial.o -o bootloader.rom

bootloader.o: .FORCE_CLEAN
	ca65 bootloader.s

io.o:
	ca65 io.s

lcd.o:
	ca65 lcd.s

serial.o:
	ca65 serial.s

.FORCE_CLEAN: clean

clean:
	rm -f bootloader.o io.o lcd.o serial.o bootloader.rom