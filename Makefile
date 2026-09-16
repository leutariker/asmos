all: boot.img

boot.img: mkboot.py stage1.out stage2.out stage3.out
	python3 $^ $@

%.out: %.asm
	fasm $< $@

run: boot.img
	qemu-system-i386 -fda boot.img -d cpu_reset -no-reboot

clean:
	rm -f *.out boot.img

.PHONY: all run clean