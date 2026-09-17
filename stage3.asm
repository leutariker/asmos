format binary
use32
org 0x10000

start:
    cli

    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw

@@: hlt
    jmp @b