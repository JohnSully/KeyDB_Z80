all: keydb.bin emulator
	@echo "Use make run to try it out"

clean:
	rm -f emulator
	rm -f keydb.bin
	rm -f keydb.hex

keydb.bin: keydb.asm commands.asm
	z80asm keydb.asm -o keydb.bin
	objcopy -I binary -O ihex keydb.bin keydb.hex

emulator: emulator.cpp
	g++ emulator.cpp -o emulator -lz80ex

run:
	socat TCP4-LISTEN:6379,reuseaddr,fork Exec:./emulator
