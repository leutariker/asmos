OUT=boot.img
SYS=sys/stage1.out sys/stage2.out sys/stage3.out
PROGS=progs/cmd.out progs/test.out progs/bga.out progs/init.out
CFLAGS=-Isys -m64 -nostdlib -static
LDFLAGS=-Wl,-Ttext=0x1000 -Wl,-e,_start -Wl,-section-alignment=0x1000

all: boot.img

$(OUT): mkboot.py $(SYS) $(PROGS) README.txt init.txt
	python3 $^ $@

%.out: %.c sys/crt0.h
	tcc -o $@ $(CFLAGS) $(LDFLAGS) $<

%.out: %.asm
	fasm $< $@

run: $(OUT)
	qemu-system-x86_64 -m 768M -hda $(OUT) -no-reboot -debugcon stdio

debug: $(OUT)
	qemu-system-x86_64 -m 768M -hda $(OUT) -no-reboot -debugcon stdio -d cpu_reset,int -D qemu.log

format:
	find . -type f \( -name "*.c" -o -name "*.h" \) -exec clang-format --style="file:./.clang-format" -i {} +

clean:
	rm -f $(SYS) $(PROGS) $(OUT)

.PHONY: all run clean
