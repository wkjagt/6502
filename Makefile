all: os.rom

clean:
	rm -f *.lst *.map *.o *.rom

%.o: %.s
	ca65 -o $@ $<

%.rom: %.o os.cfg
	ld65 -C os.cfg -o $@ $<

.PHONY: all clean