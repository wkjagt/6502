assemble:
	vasm6502_oldstyle -Fbin -dotdir -c02 bootloader.asm -o bootloader.rom -L bootloader.lst

upload_rom:
	minipro -p AT28C256 -w bootloader.rom -s 

load:
	vasm6502_oldstyle -Fbin -dotdir -c02 $(program).asm -o $(program).rom
	ROM=$(program).rom python3 upload_script/upload_program.py
