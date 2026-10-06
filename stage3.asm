;;;;;;;;;;;;
;; TABLES ;;
;;;;;;;;;;;;

SYSCALL_EXIT = 0
SYSCALL_RUN = 1
SYSCALL_MALLOC = 2
SYSCALL_FREE = 3
SYSCALL_GETC = 4

;;;;;;;;;;;;
;; MACROS ;;
;;;;;;;;;;;;

macro pushaq {
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rbp
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx
    push rax
}

macro popaq {
    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rbp
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15
}

;;;;;;;;;;
;; MAIN ;;
;;;;;;;;;;

IS_X64=1 ; for include/

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
    jnc $ ; halt if no apic
    bt edx, 5
    jnc $ ; halt if no msr

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

    ; set tss rsp0
    mov qword [tss.rsp0], rsp

    ; link tss
    mov rax, tss
    mov [gdt_tss.base_low], ax
    shr rax, 16
    mov [gdt_tss.base_mid], al
    shr rax, 8
    mov [gdt_tss.base_high], al
    shr rax, 8
    mov [gdt_tss.base_upper], eax

    ; load tss
    mov ax, 0x28
    ltr ax

    ; load idt
    lidt [idtr]

    ; init irqs
    mov qword [irqs + (0x20 * 8)], timer_handler
    mov qword [irqs + (0x21 * 8)], keyboard_handler

    ; init syscalls
    mov qword [syscalls + (SYSCALL_EXIT*8)], exit
    mov qword [syscalls + (SYSCALL_RUN*8)], run
    mov qword [syscalls + (SYSCALL_MALLOC * 8)], malloc
    mov qword [syscalls + (SYSCALL_FREE * 8)], free
    mov qword [syscalls + (SYSCALL_GETC * 8)], getc

    ; load apic code into memory and init
    mov rsi, apic_out
    call load_binary
    lea rax, [lapic] ; pass ptr of apic base address
    call rdx

    ; load bga code into memory and init
    mov rsi, bga_out
    call load_binary
    mov rax, 1024
    mov rbx, 768
    mov rcx, 32
    call rdx

    ; enable interrupts
    sti

    ; allow 0xE9 for debug output in init
    mov di, 0xE9
    mov esi, 1
    call config_port

    ; run cmd
    mov rsi, cmd_out
    mov rax, SYSCALL_RUN
    int 0x80

    ; disable 0xE9
    mov di, 0xE9
    mov esi, 0
    call config_port

    ; poll
    jmp $

;;;;;;;;;;;;;;;;;;;;;;
;; SYSTEM FUNCTIONS ;;
;;;;;;;;;;;;;;;;;;;;;;

exec:

; in:
;   - rdx: entry point

    push rbp
    mov [exit.stack], rsp ; save exit stack
    mov [tss.rsp0], rsp ; set tss rsp0 to exit stack

    ; alloc 16k user stack
    mov rcx, 0x4000
    mov rax, SYSCALL_MALLOC
    int 0x80
    test rax, rax
    jz @f

    ; point rbx to top of user stack
    add rax, 0x4000
    mov rbx, rax

    push 0x1B ; ss
    push rbx ; rsp
    pushf
    pop rax
    or rax, 0x200 ; enable interrupts
    push rax ; flags
    push 0x23 ; cs
    push rdx ; rip

    mov ax, 0x1B
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    iretq

@@: ret

load_binary:

; in:
;   - rsi: file name to load
; out:
;   - cf: set if error
;   - rdx: entry point of loaded binary

    push rbx
    push rcx

    ; alloc 64k
    mov rcx, 0x10000
    mov rax, SYSCALL_MALLOC
    int 0x80
    test rax, rax
    jz .error
    
    push rax ; save load ptr

    ; read file into scratch
    mov rdi, 0x80000
    call fat16_read_file
    jc .error

    ; reloc elf binary from scratch (rax) into allocated memory (rbx)
    pop rbx
    mov rax, 0x80000
    call elf64_load_file
    jc .error

    ; rdx = entry point
    mov rdx, rax

    pop rcx
    pop rbx
    clc
    ret

    .error:
        pop rcx
        pop rbx
        stc
        ret

run:

; in:
;   - rsi: file name of binary to run

    call load_binary
    jc @f
    call exec
@@: ret

exit:
    mov rsp, [.stack] ; restore rsp
    pop rbp
    ret
    .stack: dq 0

malloc:

; in:
;   - rcx: number of bytes to alloc
; out:
;   - rax: ptr to alloced memory (0=fail)

    test rcx, rcx
    jz @f

    ; align heap top by 16
    mov r8, [heap_top]
    add r8, 15
    and r8, -16

    ; calc new top
    lea r9, [r8 + rcx]
    jc @f

    ; enforce heap limit
    mov rax, 0x40000000
    cmp r9, rax
    jae @f

    ; commit allocation
    mov [heap_top], r9
    mov rax, r8
    ret

    ; error
@@: xor rax, rax
    ret

free:
    ret

getc:

; out:
;   - al: scancode (0 if none available)

    push rbx
    push rsi

    mov rbx, [scancodes.write_ptr]
    mov rsi, [scancodes.read_ptr]
    cmp rsi, rbx ; check if buffer is empty 
    je .empty

    mov al, [rsi]
    inc rsi ; advance read pointer

    ; wrap around
    cmp rsi, scancodes.buf + 256
    jb @f
    mov rsi, scancodes.buf

@@: mov [scancodes.read_ptr], rsi ; save read ptr
    jmp .done

    .empty:
        xor al, al

    .done:
        pop rsi
        pop rbx
        ret

;;;;;;;;;;;;;;
;; HANDLERS ;;
;;;;;;;;;;;;;;

keyboard_handler:
    in al, 0x60
    mov rbx, [scancodes.read_ptr]
    mov [rbx], al
    inc rbx

    ; wrap around write pointer
    cmp rbx, scancodes.buf + 256
    jb @f
    mov rbx, scancodes.buf

@@: mov [scancodes.write_ptr], rbx
    ret

timer_handler:
    ret

syscall_handler:
    pushaq

    mov ax, 0x08
    mov ds, ax
    mov es, ax

    mov rax, [rsp + 0]
    cmp rax, 0xFF
    jae .restore

    mov r11, [syscalls + (rax * 8)]
    test r11, r11
    jz .restore

    mov rax, [rsp + 0]
    mov rbx, [rsp + 8]
    mov rcx, [rsp + 16]
    mov rdx, [rsp + 24]
    mov rsi, [rsp + 32]
    mov rdi, [rsp + 40]

    call r11 ; call syscall handler

    mov [rsp + 0], rax
    mov [rsp + 8], rbx 
    mov [rsp + 16], rcx
    mov [rsp + 24], rdx
    mov [rsp + 32], rsi
    mov [rsp + 40], rdi

    ; check whether to return to ring3 or ring0
@@: mov ax, [rsp + 128] ; +128 = cs
    and ax, 3
    jz .ring0

    .restore:
        mov ax, [rsp + 128] ; +128 = cs
        and ax, 3
        jz .ring0

    .ring3:
        mov ax, 0x1B
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        jmp .done

    .ring0:
        mov ax, 0x08
        mov ds, ax
        mov es, ax

    .done:
        popaq
        iretq

exception_handler:

; in:
;   - rax: exception number

    pushaq

    mov rax, [rsp + 120]

    cmp rax, 31
    jle .error

    cmp rax, 255
    je .done ; spurious

    ; find irq handler
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
        add rsp, 16 ; cleanup vector and error code
        iretq

    .error:
        mov rcx, [rsp+120]
        popaq
        cli
    @@: hlt
        jmp @b

;;;;;;;;;;;;;;;
;; FUNCTIONS ;;
;;;;;;;;;;;;;;;

config_port:

; in:
;   - di: port number
;   - esi: 0 = disable, 1 = enable

    movzx eax, di
    test esi, esi
    jz @f

    btr [tss.io], eax ; allow
    ret

@@: bts [tss.io], eax ; deny
    ret

;;;;;;;;;;;;;;;;;;;
;; EXECABLE DATA ;;
;;;;;;;;;;;;;;;;;;;

idt_stubs:
rept 256 n:0 {
    align 16
    .stub#n:
        if (((1 shl 8) or\
             (1 shl 10) or\
             (1 shl 11) or\
             (1 shl 12) or\
             (1 shl 13) or\
             (1 shl 14) or\
             (1 shl 17) or\
             (1 shl 21)) shr n) and 1 = 0
            push 0
        end if

        push n
        jmp exception_handler
}

align 8
irqs: times 256 dq @f
syscalls: times 256 dq @f
@@: ret

include "include/ata.inc"
include "include/elf64.inc"
include "include/fat16.inc"

;;;;;;;;;;;;;;;;;;;
;; READABLE DATA ;;
;;;;;;;;;;;;;;;;;;;

segment readable
apic_out: mk8.3 "APIC", "OUT"
bga_out: mk8.3 "BGA", "OUT"
cmd_out: mk8.3 "CMD", "OUT"

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
        if n = 0x80
            dw (syscall_handler and 0xFFFF)
            dw 0x10
            db 0
            db 0xEF ; dpl3 for syscall gate
            dw ((syscall_handler shr 16) and 0xFFFF)
            dd ((syscall_handler shr 32) and 0xFFFFFFFF)
            dd 0
        else
            dw ((idt_stubs.stub#n) and 0xFFFF)
            dw 0x10
            db 0
            db 0xEE ; interrupt gate
            dw ((idt_stubs.stub#n shr 16) and 0xFFFF)
            dd ((idt_stubs.stub#n shr 32) and 0xFFFFFFFF)
            dd 0
        end if
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
    .limit: dw (tss.end-tss-1)
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

;;;;;;;;;;;;;;;;;;;
;; WRITABLE DATA ;;
;;;;;;;;;;;;;;;;;;;

segment readable writable
heap_top: dq 0x6400000
lapic: dq 0

scancodes:
    .buf: times 256 db 0
    .read_ptr: dq scancodes.buf
    .write_ptr: dq scancodes.buf

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
    .base: dw tss.io-tss
    .io: times 8192+1 db 0xFF
    .end:

align 16
rb 16384
stack_top: