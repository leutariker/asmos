INCLUDE=$(wildcard include/*.inc)

all: boot.img

boot.img: mkboot.py stage1.out stage2.out stage3.out hello.out
	python3 $^ $@

%.out: %.asm $(INCLUDE)
	fasm $< $@

run: boot.img
	qemu-system-x86_64 -hda boot.img -no-reboot -debugcon stdio

clean:
	rm -f stage1.out stage2.out stage3.out hello.out boot.img

.PHONY: all run clean