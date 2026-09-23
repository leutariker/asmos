macro mk8.3 name, ext {
    local .start
    .start: db name
    times 8 - ($ - .start) db ' '
    db ext
}

macro pushaq {
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
}

macro popaq {
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
}

format elf64 executable 3 at 0x100000
use32
entry start
segment readable executable

start:
    cli
    cld

    ; check for cpu features
    mov eax, 0x80000001
    cpuid
    bt edx, 9
    jnc reboot ; reboot if no apic
    bt edx, 5
    jnc reboot ; reboot if no msr

    ; load new gdt
    lgdt [gdtr]

    ; enable pae
    mov eax, cr4
    or eax, (1 shl 5)
    mov cr4, eax

    ; load pml4
    mov eax, pml4
    mov cr3, eax

    ; set lm-bit
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 shl 8)
    wrmsr

    ; enable paging
    mov eax, cr0
    or eax, (1 shl 31)
    mov cr0, eax

    ; load gdt
    jmp far 0x10:@f

    use64
@@: mov ax, 0x08
    mov ds, ax
    mov es, ax
    mov ss, ax
    xor ax, ax
    mov gs, ax
    mov fs, ax

    ; set up new stack
    mov rsp, stack_top
    mov rbp, rsp

    ; load idt
    lidt [idtr]

    ; load apic code into memory
    mov rsi, initapic_out
    call load_prog
    mov qword [initapic], rdx

    ; init apic
    lea rax, [lapic] ; pass ptr of apic base address
    call qword [initapic]

    ; load hello world into memory
    mov rsi, hello_out
    call load_prog
    mov qword [hello], rdx

    ; load initbga into memory
    mov rsi, initbga_out
    call load_prog
    mov qword [initbga], rdx

    ; load keyboard handler into memory
    mov rsi, keyhndlr_out
    call load_prog
    mov qword [irq_handlers.keyboard], rdx

    ; load timer handler into memory
    mov rsi, tmrhndlr_out
    call load_prog
    mov qword [irq_handlers.timer], rdx

    ; init bga driver
    mov rax, 1024
    mov rbx, 768
    mov rcx, 32
    call qword [initbga]

    ; run hello world
    call qword [hello]

    sti
@@: hlt
    jmp @b

load_prog:

; in:
;   - rsi: file name to load
; out:
;   - cf: set if error
;   - rdx: entry point of loaded binary

    push rax
    push rbx

    ; read file into scratch
    mov rdi, 0x80000
    call fat16_read_file
    jc .error

    ; reloc elf binary into memory
    mov rax, 0x80000
    mov rbx, [.exec_ptr]
    call elf64_load_file
    jc .error

    ; rdx = entry point
    mov rdx, rax

    ; align exec ptr to next 64kb boundary
    mov rax, [.exec_ptr]
    add rax, 0x10000
    and rax, -0x10000
    mov [.exec_ptr], rax

    pop rbx
    pop rax

    clc
    ret

    .error:
        pop rbx
        pop rax
        stc
        ret

    .exec_ptr: dq 0x200000

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
;   - rax: vector number
;   - rbx: error code (if rax is 8,10,11,12,13,14,17,21)

    pushaq

    cmp rax, 31
    jle .error

    .irq:
        sub rax, 32 ; convert vector to irq

        cmp rax, 223
        je @f ; spurious irq

        mov rbx, [irq_handlers + rax*8]
        test rbx, rbx
        jz .eoi
        call rbx

    .eoi:
        mov rcx, [lapic]
        mov dword [rcx + 0xB0], 0
@@:     popaq
        iretq

    .error:
        popaq
        mov rsi, error_messages
        mov rcx, rax
        shl rcx, 5 ; 32 bytes per message
        add rsi, rcx
        call debug
        cli
@@:     hlt
        jmp @b

debug:

; in:
;   - rsi: string to print

    mov al, [rsi]
    test al, al
    jz @f
    out 0xE9, al
    inc rsi
    jmp debug
@@: ret

idt_stubs:
rept 256 n:0 {
    .stub#n:
        if n = 8
            pop rbx
        else if n = 10
            pop rbx
        else if n = 11
            pop rbx
        else if n = 12
            pop rbx
        else if n = 13
            pop rbx
        else if n = 14
            pop rbx
        else if n = 17
            pop rbx
        else if n = 21
            pop rbx
        end if

        mov rax, n

        jmp exception_handler
        times 16-($ - .stub#n) db 0
}

initbga: dq 0
hello: dq 0
initapic: dq 0

IS_X64=1
include "include/ata.inc"
include "include/elf64.inc"
include "include/fat16.inc"

segment readable
initapic_out: mk8.3 "INITAPIC", "OUT"
hello_out: mk8.3 "HELLO", "OUT"
initbga_out: mk8.3 "INITBGA", "OUT"
keyhndlr_out: mk8.3 "KEYHNDLR", "OUT"
tmrhndlr_out: mk8.3 "TMRHNDLR", "OUT"

align 4096
pml4:
    dq pdpt or 0x3
    times 511 dq 0

align 4096
pdpt:
    dq pd0 or 0x3
    times 2 dq 0
    dq pd3 or 0x3 ; map ioapic/apic
    times 508 dq 0

align 4096
pd0:
    rept 512 n:0 {
        dq (n * 0x200000) or 0x83
    }

align 4096
pd3:
    rept 512 n:0 {
        dq (0xC0000000 + (n * 0x200000)) or 0x83
    }

align 16
idt:
    rept 256 n:0 {
    .idt_entry#n:
        dw ((idt_stubs.stub#n) and 0xFFFF) ; isr low
        dw 0x10 ; cs
        db 0 ; ist
        db 0x8E ; attr
        dw ((idt_stubs.stub#n shr 16) and 0xFFFF) ; isr mid
        dd ((idt_stubs.stub#n shr 32) and 0xFFFFFFFF) ; isr high
        dd 0 ; reserved
    }
idtr:
    dw $ - idt - 1
    dq idt

align 16
gdt:
    dq 0x0000000000000000
    dq 0x00CF92000000FFFF
    dq 0x00AF9A000000FFFF
gdtr:
    dw $ - gdt - 1
    dq gdt

irq_handlers:
    .timer: dq 0
    .keyboard: dq 0
    times 224 dq 0

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
lapic: dq 0

align 16
stack_btm:
rb 16384
stack_top: