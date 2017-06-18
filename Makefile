all : json.bin

run : json.bin 
	./openmsx -machine Panasonic_FS-A1GT -diska test

json.bin : json.asm
	./sjasmplus json.asm --lst=json.lst --sym=json.sym
	mkdir -p test
	cp json.bin test

