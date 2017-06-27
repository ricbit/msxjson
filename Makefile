all : json.bin

run : json.bin 
	rm -rf test/autoexec.bas
	./openmsx -machine Panasonic_FS-A1GT -diska test

test : json.bin
	cp test/test.bas test/autoexec.bas
	./openmsx -machine Panasonic_FS-A1GT -diska test -script test.tcl

json.bin : json.asm
	./sjasmplus json.asm --lst=json.lst --sym=json.sym
	mkdir -p test
	cp json.bin test

