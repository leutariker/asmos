format elf64 executable 3 at 0x1000
include "include/crt0.inc"
segment readable executable writable

main:
    lea rsi, [readme_txt]
    mov rax, 5
    int 0x80

    mov rbx, rax
@@: mov al, [rbx]
    test al, al
    jz @f
    out 0xE9, al
    inc rbx
    jmp @b

@@: ret

segment readable
readme_txt: db "README  TXT"