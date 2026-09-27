format elf64 executable 3 at 0x1000
include "include/crt0.inc"
segment readable executable writable

main:
    lea rsi, [hello_out]
    mov rax, SYSCALL_RUN
    int 0x80
    ret

segment readable
include "include/syscalls.inc"
hello_out: db "HELLO   OUT", 0