format ELF executable 3 at 0x200000
use32
entry start
segment readable executable writable

start:
    mov al, 'X'
    out 0xE9, al

    ret