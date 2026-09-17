format ELF executable 3 at 0x10000
use32
entry start
segment readable executable

start:
    cli
    lidt [idtr]

    mov al, 0xFF
    out PIC1, al
    out PIC2, al

    sti

    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw

@@: hlt
    jmp @b

exception_handler:
    pop eax
    iret

idt_stubs:
    rept 256 n:0 {
        push n
        jmp exception_handler
        align 8
    }

include "include/pic.inc"

segment readable writable
idt:
    rept 256 n:0 {
        dw ((idt_stubs + (16 * n)) and 0xFFFF) ; isr low
        dw 0x10 ; cs
        db 0 ; reserved
        db 0x8E ; attr
        dw ((idt_stubs + (16 * n)) shr 16) ; isr high
    }
idtr:
    dw idtr - idt - 1
    dd idt