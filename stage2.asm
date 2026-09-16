format binary
use16
org 0x8000

start:
    cli

    mov al, 'A'
    mov ah, 0x0E
    int 0x10

@@: hlt
    jmp @b
    
times 2048 dd 0