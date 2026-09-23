format ELF executable 3 at 0x1000
use64
entry start
segment readable executable writable

start:
    mov al, 'X'
    out 0xE9, al

    ret