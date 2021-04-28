assemble:
	./vasm/vasm6502_oldstyle -Fbin -dotdir bootloader.asm -o bootloader.rom

upload_rom:
	minipro -p AT28C256 -w bootloader.rom

load:
	./vasm/vasm6502_oldstyle -Fbin -dotdir $(program).asm -o $(program).rom
	ROM=$(program).rom ruby upload_script/serial.rb
