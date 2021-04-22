assemble:
	./vasm/vasm6502_oldstyle -Fbin -dotdir bootloader.asm -o bootloader.rom

upload_rom:
	minipro -p AT28C256 -w bootloader.rom

upload_program:
	cd upload_script
	bundle exec ruby serial.rb
	cd ..