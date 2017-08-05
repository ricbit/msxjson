all : json.bin

run : json.bin 
	rm -rf test/autoexec.bas
	./openmsx -machine Panasonic_FS-A1GT -diska test

test : json.bin test/test.bas
	cp test/test.bas test/autoexec.bas
	./openmsx -machine Panasonic_FS-A1GT -diska test -script test.tcl

coverage : json.bin test/test.bas coverage.tcl coverage.py
	cp test/test.bas test/autoexec.bas
	./openmsx -machine Panasonic_FS-A1GT -diska test -script coverage.tcl
	python coverage.py > coverage.html

json.bin : json.asm
	./sjasmplus json.asm --lst=json.lst --sym=json.sym
	mkdir -p test
	cp json.bin test

