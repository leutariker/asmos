OUT=boot.img
SYS=sys/stage1.out sys/stage2.out sys/stage3.out
DRIVERS=drivers/apic.out drivers/bga.out
PROGS=progs/cmd.out progs/test.out
INCLUDE=$(wildcard include/*.inc)

all: boot.img

$(OUT): mkboot.py $(SYS) $(DRIVERS) $(PROGS) README.txt
	python3 $^ $@

%.out: %.asm $(INCLUDE)
	fasm $< $@

run: $(OUT)
	qemu-system-x86_64 -hda $(OUT) -no-reboot -debugcon stdio

debug: $(OUT)
	qemu-system-x86_64 -hda $(OUT) -no-reboot -debugcon stdio -d cpu_reset,int -D qemu.log

clean:
	rm -f $(SYS) $(DRIVERS) $(PROGS) $(OUT)

.PHONY: all run clean