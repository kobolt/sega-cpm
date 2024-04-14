
all: sega-cpm.sc

sega-cpm.sc: bootloader.cim cpm22.bin
	./create_banked_rom.py disk-a.img disk-b.img disk-c.img disk-d.img

bootloader.cim: bootloader.asm cbios.cim cpm22.bin font.bin
	zmac bootloader.asm --od . --oo cim,lst

cbios.cim: cbios.asm sgterm.asm
	zmac cbios.asm --od . --oo cim,lst

.PHONY: clean
clean:
	rm -f *.cim *.lst *.sc

