link: bootloader.o serial.o
	ld65 -C bootloader.cfg bootloader.o serial.o -o bootloader.rom

bootloader.o: .FORCE_CLEAN
	ca65 bootloader.asm

serial.o:
	ca65 serial.asm

.FORCE_CLEAN: clean

clean:
	rm -f bootloader.o serial.o bootloader.rom