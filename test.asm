format elf64 executable 3 at 0x1000
use64
entry start
segment readable executable writable

start:
    mov al, 'U'
    out 0xE9, al
    
    mov rcx, 0x01
    int 0x80