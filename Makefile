OUT=boot.img
SYS=stage1.out stage2.out stage3.out
PROGS=apic.out bga.out cmd.out test.out
INCLUDE=$(wildcard include/*.inc)

all: boot.img

$(OUT): mkboot.py $(SYS) $(PROGS)
	python3 $^ $@

%.out: %.asm $(INCLUDE)
	fasm $< $@

run: $(OUT)
	qemu-system-x86_64 -hda $(OUT) -no-reboot -debugcon stdio

debug: $(OUT)
	qemu-system-x86_64 -hda $(OUT) -no-reboot -debugcon stdio -d cpu_reset,int -D qemu.log

clean:
	rm -f $(SYS) $(PROGS) $(OUT)

.PHONY: all run clean