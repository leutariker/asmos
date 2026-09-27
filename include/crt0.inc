include "include/syscalls.inc"
use64
entry start

start:
    call main
    mov rax, SYSCALL_EXIT
    int 0x80
@@: hlt
    jmp @b