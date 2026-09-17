format binary
use32
org 0x10000

start:
    cli

    mov al, 'X'
    out 0xE9, al

@@: hlt
    jmp @b