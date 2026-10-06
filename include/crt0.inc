use64
entry start

start:
    call main
    mov rax, 0 ; exit syscall
    int 0x80
@@: hlt
    jmp @b