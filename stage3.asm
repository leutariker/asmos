IS_X64=1 ; for include/

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
    mov rsp, sys_stack
    mov rbp, rsp

    ; link tss
    mov rax, tss
    mov [gdt_tss.base_low], ax
    shr rax, 16
    mov [gdt_tss.base_mid], al
    shr rax, 8
    mov [gdt_tss.base_high], al
    shr rax, 8
    mov [gdt_tss.base_upper], eax

    ; set tss rsp0
    mov qword [tss.rsp0], sys_stack

    ; load tss
    mov ax, 0x28
    ltr ax

    ; load idt
    lidt [idtr]

    ; load apic code into memory and init
    mov rsi, initapic_out
    call load_binary
    lea rax, [lapic] ; pass ptr of apic base address
    call rdx

    ; load bga code into memory and init
    mov rsi, initbga_out
    call load_binary
    mov rax, 1024
    mov rbx, 768
    mov rcx, 32
    call rdx

    ; load keyboard handler into memory and wire irq
    mov rsi, keyhndlr_out
    call load_binary
    mov qword [irqs+(0x21*8)], rdx

    ; load timer handler into memory and wire irq
    mov rsi, tmrhndlr_out
    call load_binary
    mov qword [irqs+(0x20*8)], rdx

    ; load hello world into memory and wire syscall
    mov rsi, hello_out
    call load_binary
    mov qword [syscalls+(0xFF*8)], rdx

    ; init syscall handler
    mov qword [irqs+(0x80*8)], syscall_handler

    ; init exit syscall
    mov qword [syscalls+(0x01*8)], exit

    ; run hello world as a binary
    mov rsi, hello_out
    call load_binary
    call exec

    ; run hello world as a syscall
    mov rcx, 0xFF
    int 0x80

    sti
@@: hlt
    jmp @b

exec:

; in:
;   - rdx: entry point

    pop rax
    mov [exit.rip], rax
    mov [exit.stack], rsp

    ; put exit stub on stack so ret = exit syscall
    mov rax, .exit_stub
    mov [user_stack - 8], rax

    mov ax, 0x1B
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    push 0x1B ; ss
    lea rax, [user_stack - 8]
    push rax ; rsp
    push 0x3202 ; rflags (sti, iopl=3)
    push 0x23 ; cs
    push rdx

    iretq

    .exit_stub:
        mov rcx, 0x01 ; exit syscall
        int 0x80

load_binary:

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
    mov rbx, [.load_ptr]
    call elf64_load_file
    jc .error

    ; rdx = entry point
    mov rdx, rax

    ; align exec ptr to next 64kb boundary
    mov rax, [.load_ptr]
    add rax, 0x10000
    and rax, -0x10000
    mov [.load_ptr], rax

    pop rbx
    pop rax

    clc
    ret

    .error:
        pop rbx
        pop rax
        stc
        ret

    .load_ptr: dq 0x200000

reboot:
    cli
@@: in al, 0x64
    test al, 0x02
    jnz @b
    mov al, 0x01
    out 0x64, al
    hlt

exit:
    mov ax, 0x08
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, [exit.stack]
    jmp qword [exit.rip]

syscall_handler:

; in:
;   - rcx: syscall number

    mov rax, [syscalls+(rcx*8)]
    test rax, rax
    jz @f
    call rax
@@: ret

exception_handler:

; in:
;   - rax: exception number

    pushaq

    cmp rax, 31
    jle .error

    cmp rax, 255
    je .done ; spurious

    mov rbx, [irqs + rax*8]
    test rbx, rbx
    jz .eoi
    call rbx

    .eoi:
        mov rcx, [lapic]
        test rcx, rcx
        jz .done
        mov dword [rcx + 0xB0], 0

    .done:
        popaq
        iretq

    .error:
        popaq
        mov rsi, error_messages
        mov rcx, rax
        shl rcx, 5 ; 32 bytes per message
        add rsi, rcx
        call puts
        cli
    @@: hlt
        jmp @b

puts:

; in:
;   - rsi: string to print

    mov al, [rsi]
    test al, al
    jz @f
    out 0xE9, al
    inc rsi
    jmp puts
@@: ret

idt_stubs:
rept 256 n:0 {
    align 16
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
}

irqs: times 256 dq @f
syscalls: times 256 dq @f
@@: ret

include "include/ata.inc"
include "include/elf64.inc"
include "include/fat16.inc"

segment readable
initapic_out: mk8.3 "INITAPIC", "OUT"
initbga_out: mk8.3 "INITBGA", "OUT"
keyhndlr_out: mk8.3 "KEYHNDLR", "OUT"
tmrhndlr_out: mk8.3 "TMRHNDLR", "OUT"
hello_out: mk8.3 "HELLO", "OUT"

align 4096
pml4:
    dq pdpt or 0x7
    times 511 dq 0

align 4096
pdpt:
    dq pd0 or 0x7
    times 2 dq 0
    dq pd3 or 0x7 ; map ioapic/apic
    times 508 dq 0

align 4096
pd0:
    rept 512 n:0 {
        dq (n * 0x200000) or 0x87
    }

align 4096
pd3:
    rept 512 n:0 {
        dq (0xC0000000 + (n * 0x200000)) or 0x87
    }

align 16
idt:
    rept 256 n:0 {
    .idt_entry#n:
        dw ((idt_stubs.stub#n) and 0xFFFF) ; isr low
        dw 0x10 ; cs
        db 0 ; ist
        if n = 0x80
            db 0xEE ; dpl 3 for syscall
        else
            db 0x8E ; interrupt gate
        end if
        dw ((idt_stubs.stub#n shr 16) and 0xFFFF) ; isr mid
        dd ((idt_stubs.stub#n shr 32) and 0xFFFFFFFF) ; isr high
        dd 0 ; reserved
    }
idtr:
    .limit: dw $ - idt - 1
    .base: dq idt

align 16
gdt:
    .null: dq 0x0000000000000000 ; null
    .sys_ds: dq 0x00CF92000000FFFF ; kernel ds
    .sys_cs: dq 0x00AF9A000000FFFF ; kernel cs
    .user_ds: dq 0x00CFF2000000FFFF ; user ds
    .user_cs: dq 0x00AFFA000000FFFF ; user cs
gdt_tss:
    .limit: dw 103
    .base_low: dw 0
    .base_mid: db 0
    .flags: db 0x89
    .limit_high: db 0
    .base_high: db 0
    .base_upper: dd 0
    .reserved: dd 0
gdtr:
    .limit: dw $ - gdt - 1
    .base: dq gdt

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

exit.stack: dq 0
exit.rip: dq 0

align 16
tss:
    .reserved: dd 0
    .rsp0: dq 0
    .rsp1: dq 0
    .rsp2: dq 0
    .reserved2: dq 0
    .ist: times 7 dq 0
    .reserved3: dq 0
    .reserved4: dw 0
    .base: dw 104

align 16
rb 16384
user_stack:

align 16
rb 16384
sys_stack: