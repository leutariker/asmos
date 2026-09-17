format ELF executable 3 at 0x10000
use32
entry start
segment readable executable

start:
    cli

    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw

@@: hlt
    jmp @b