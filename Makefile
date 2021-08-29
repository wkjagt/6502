assemble:
	vasm6502_oldstyle -Fbin -dotdir -c02 bios/bios.asm -o bios/bios.rom -L bios/bios.lst

write_bios:
	minipro -p AT28C256 -w bios/bios.rom -s 

load:
	vasm6502_oldstyle -Fbin -dotdir -c02 monitor/$(program).asm -o monitor/$(program).rom
	ROM=monitor/$(program).rom python3 upload_script/upload_program.py
