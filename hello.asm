format elf64 executable 3 at 0x1000
use64
entry start
segment readable executable writable

start:
    lea rsi, [hello_world]
    call debug
    ret

debug:

; in:
;   - rsi: string to print

    mov al, [rsi]
    test al, al
    jz @f
    out 0xE9, al
    inc rsi
    jmp debug
@@: ret

segment readable
hello_world: db "Hello, world!", 0x0D, 0x0A, 0