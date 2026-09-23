macro mk8.3 name, ext {
    local .start
    .start: db name
    times 8 - ($ - .start) db ' '
    db ext
}

format ELF executable 3 at 0x10000
use32
entry start
segment readable executable writable

start:
    cli

    ; load new gdt
    lgdt [gdtr]
    jmp far 0x10:@f
@@: mov ax, 0x08
    mov ds, ax
    mov es, ax
    mov ss, ax
    xor ax, ax
    mov gs, ax
    mov fs, ax

    ; set up new stack
    mov esp, stack_top
    mov ebp, esp

    ; load idt
    lidt [idtr]

    ; load apic code into memory
    mov esi, initapic_out
    call load_prog
    mov [initapic], edx

    ; init apic
    lea eax, [lapic] ; pass ptr of apic base address
    call dword [initapic]

    ; load hello world into memory
    mov esi, hello_out
    call load_prog
    mov [hello], edx

    ; load initbga into memory
    mov esi, initbga_out
    call load_prog
    mov [initbga], edx

    ; load keyboard handler into memory
    mov esi, keyhndlr_out
    call load_prog
    mov [irq_handlers.keyboard], edx

    ; load timer handler into memory
    mov esi, tmrhndlr_out
    call load_prog
    mov [irq_handlers.timer], edx

    ; init bga driver
    mov eax, 1024
    mov ebx, 768
    mov cx, 32
    call dword [initbga]

    ; run hello world
    call dword [hello]

    sti
@@: hlt
    jmp @b

load_prog:

; in:
;   - esi: file name to load
; out:
;   - cf: set if error
;   - edx: entry point of loaded binary

    push eax
    push ebx

    ; read file into scratch
    mov edi, 0x80000
    call fat16_read_file
    jc .error

    ; reloc elf binary into memory
    mov eax, 0x80000
    mov ebx, [.exec_ptr]
    call elf32_load_file
    jc .error

    ; edx = entry point
    mov edx, eax
    
    ; align exec ptr to next 64kb boundary
    mov eax, [.exec_ptr]
    add eax, 0x10000
    and eax, 0xFFFF0000
    mov [.exec_ptr], eax

    pop ebx
    pop eax

    clc
    ret

    .error:
        pop ebx
        pop eax
        stc
        ret

    .exec_ptr: dd 0x200000

reboot:
    cli
@@: in al, 0x64
    test al, 0x02
    jnz @b
    mov al, 0xFE
    out 0x64, al
    hlt

exception_handler:

; in:
;   - eax: vector number
;   - ebx: error code (if eax is 8,10,11,12,13,14,17,21)

    pushad

    cmp eax, 31
    jle .error

    .irq:
        sub eax, 32 ; convert vector to irq

        cmp eax, 223
        je @f ; spurious irq

        mov ebx, [irq_handlers + eax*4]
        test ebx, ebx
        jz .eoi
        call ebx

    .eoi:    
        mov ecx, [lapic]
        mov dword [ecx + 0xB0], 0
@@:     popad
        iret
    
    .error:    
        popad
        mov esi, error_messages
        mov ecx, eax
        shl ecx, 5 ; 32 bytes per message
        add esi, ecx
        call debug
        cli
@@:     hlt
        jmp @b

debug:

; in:
;   - esi: string to print

    mov al, [esi]
    test al, al
    jz @f
    out 0xE9, al
    inc esi
    jmp debug
@@: ret

idt_stubs:
rept 256 n:0 {
    .stub#n:
        if n = 8
            pop ebx
        else if n = 10
            pop ebx
        else if n = 11
            pop ebx
        else if n = 12
            pop ebx
        else if n = 13
            pop ebx
        else if n = 14
            pop ebx
        else if n = 17
            pop ebx
        else if n = 21
            pop ebx
        end if

        mov eax, n

        jmp exception_handler
        times 16-($ - .stub#n) db 0
}

initbga: dd 0
hello: dd 0
initapic: dd 0

include "include/ata.inc"
include "include/elf32.inc"
include "include/fat16.inc"

segment readable
initapic_out: mk8.3 "INITAPIC", "OUT"
hello_out: mk8.3 "HELLO", "OUT"
initbga_out: mk8.3 "INITBGA", "OUT"
keyhndlr_out: mk8.3 "KEYHNDLR", "OUT"
tmrhndlr_out: mk8.3 "TMRHNDLR", "OUT"

idt:
    rept 256 n:0 {
        dw ((idt_stubs.stub#n) and 0xFFFF) ; isr low
        dw 0x10 ; cs
        db 0 ; reserved
        db 0x8E ; attr
        dw ((idt_stubs.stub#n) shr 16) ; isr high
    }
idtr:
    dw $ - idt - 1
    dd idt

gdt:
    dq 0x0000000000000000
    dq 0x00CF92000000FFFF
    dq 0x00CF9A000000FFFF
gdtr:
    dw $ - gdt - 1
    dd gdt

irq_handlers:
    .timer: dd 0
    .keyboard: dd 0
    times 224 dd 0

error_messages:
@@: db "Divide by zero", 0
    times 32-($ - @b) db 0
@@: db "Debug", 0
    times 32-($ - @b) db 0
@@: db "Non-maskable interrupt", 0
    times 32-($ - @b) db 0
@@: db "Breakpoint", 0
    times 32-($ - @b) db 0
@@: db "Overflow", 0
    times 32-($ - @b) db 0
@@: db "Bound range exceeded", 0
    times 32-($ - @b) db 0
@@: db "Invalid opcode", 0
    times 32-($ - @b) db 0
@@: db "Device not available", 0
    times 32-($ - @b) db 0
@@: db "Double fault", 0
    times 32-($ - @b) db 0
@@: db "Coprocessor segment overrun", 0
    times 32-($ - @b) db 0
@@: db "Invalid TSS", 0
    times 32-($ - @b) db 0
@@: db "Segment not present", 0
    times 32-($ - @b) db 0
@@: db "Stack-segment fault", 0
    times 32-($ - @b) db 0
@@: db "General protection fault", 0
    times 32-($ - @b) db 0
@@: db "Page fault", 0
    times 32-($ - @b) db 0
@@: db "Reserved", 0
    times 32-($ - @b) db 0
@@: db "x87 floating-point exception", 0
    times 32-($ - @b) db 0
@@: db "Alignment check", 0
    times 32-($ - @b) db 0
@@: db "Machine check", 0
    times 32-($ - @b) db 0
@@: db "SIMD floating-point exception", 0
    times 32-($ - @b) db 0
@@: db "Virtualization exception", 0
    times 32-($ - @b) db 0
@@: db "Control protection exception", 0
    times 32-($ - @b) db 0

segment readable writable
lapic: dd 0

align 16
stack_btm: 
rb 16384
stack_top: