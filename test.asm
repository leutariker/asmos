format elf64 executable 3 at 0x1000
include "include/crt0.inc"
segment readable executable writable

main:
    mov al, 'A'
    out 0xE9, al
    mov al, 'B'
    out 0xE9, al
    mov al, 'C'
    out 0xE9, al
    mov al, 0xD
    out 0xE9, al
    mov al, 0xA
    out 0xE9, al
    ret