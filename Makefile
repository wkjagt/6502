assemble:
	./vasm/vasm6502_oldstyle -Fbin -dotdir bootloader.asm -o bootloader.rom

upload_rom:
	minipro -p AT28C256 -w bootloader.rom

load:
	./vasm/vasm6502_oldstyle -Fbin -dotdir blink_led.asm -o blink.rom
	ruby upload_script/serial.rb
