;;;;;;;;;;;;
;; TABLES ;;
;;;;;;;;;;;;

HEAP_BASE=0x6400000

SYSCALL_EXIT = 0
SYSCALL_RUN = 1
SYSCALL_MALLOC = 2
SYSCALL_FREE = 3
SYSCALL_POLL = 4
SYSCALL_READ = 5
SYSCALL_PORT = 6

PROCESS_CR3=0
PROCESS_HEAP=PROCESS_CR3+8
PROCESS_HEAPEND=PROCESS_HEAP+8
PROCESS_KRSP=PROCESS_HEAPEND+8
PROCESS_RSP0=PROCESS_KRSP+8
PROCESS_STATE=PROCESS_RSP0+8
PROCESS_FLAGS=PROCESS_STATE+8
PROCESS_SIZE=PROCESS_FLAGS+8

PROCESS_HEAP_SIZE=0x800000
PROCESSES_MAX=64

PROCESS_DEAD=0
PROCESS_ALIVE=1
PROCESS_READY=2

PROCESS_FLAG_KEY=(1 shl 0)

PIC1 = 0x20
PIC2 = 0xA0
PIC1_DATA = PIC1 + 1
PIC2_DATA = PIC2 + 1

APIC_IA32_BASE_MSR = 0x1B
APIC_IA32_BASE_MSR_ENABLE = 0x800
APIC_REG_SIVR = 0xF0
APIC_REG_EOI = 0xB0
APIC_SIVR_ENABLE = 0x100
APIC_SIVR_VECTOR = 0xFF
APIC_REG_TIMER_DIV = 0x3E0
APIC_REG_LVT_TIMER = 0x320
APIC_REG_TIMER_INIT = 0x380
APIC_REG_TIMER_CURR = 0x390
APIC_REG_ICR_LOW = 0x300
APIC_REG_ICR_HIGH = 0x310

IOAPIC_REDTBL_BASE = 0x10
IOAPIC_REG_BASE = 0xFEC00000
IOAPIC_REG_INDEX = IOAPIC_REG_BASE
IOAPIC_REG_DATA = IOAPIC_REG_BASE + 0x10

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

    ; disable the 8259 pic
    mov al, 0x11
    out PIC1, al
    out PIC2, al
    mov al, 0x20
    out PIC1_DATA, al
    mov al, 0x28
    out PIC2_DATA, al
    mov al, 0x04
    out PIC1_DATA, al
    mov al, 0x02
    out PIC2_DATA, al
    mov al, 0x01
    out PIC1_DATA, al
    out PIC2_DATA, al
    mov al, 0xFF
    out PIC1_DATA, al
    out PIC2_DATA, al

    ; enable apic
    mov ecx, APIC_IA32_BASE_MSR
    rdmsr
    or eax, APIC_IA32_BASE_MSR_ENABLE
    wrmsr

    ; store lapic base address
    mov ecx, APIC_IA32_BASE_MSR
    rdmsr
    and eax, 0xFFFFF000
    mov [lapic], rax  ; store to stage3's lapic pointer
    mov rsi, rax

    ; init lapic sivr
    mov eax, [rsi + APIC_REG_SIVR]
    or eax, APIC_SIVR_ENABLE or APIC_SIVR_VECTOR
    mov [rsi + APIC_REG_SIVR], eax

    ; config apic timer
    mov dword [rsi + APIC_REG_TIMER_DIV], 0x3 ; divide by 16
    mov dword [rsi + APIC_REG_LVT_TIMER], 0x20 or (1 shl 17) ; periodic timer
    mov dword [rsi + APIC_REG_TIMER_INIT], 0x1000000 ; initial count

    ; config irqs
    mov qword [irqs + (0x20 * 8)], timer_handler
    mov qword [irqs + (0x21 * 8)], keyboard_handler

    ; register syscalls
    mov qword [syscalls + (SYSCALL_EXIT*8)], exit
    mov qword [syscalls + (SYSCALL_RUN*8)], run
    mov qword [syscalls + (SYSCALL_MALLOC * 8)], malloc
    mov qword [syscalls + (SYSCALL_FREE * 8)], free
    mov qword [syscalls + (SYSCALL_POLL * 8)], poll
    mov qword [syscalls + (SYSCALL_READ * 8)], read
    mov qword [syscalls + (SYSCALL_PORT * 8)], config_port

    ; register boot context as process 0
    mov qword [processes.current], 0
    mov rax, pml4
    mov [processes.entries + PROCESS_CR3], rax
    mov qword [processes.entries + PROCESS_HEAP], HEAP_BASE
    mov qword [processes.entries + PROCESS_HEAPEND], HEAP_BASE + PROCESS_HEAP_SIZE
    mov qword [processes.entries + PROCESS_RSP0], stack_top
    mov qword [processes.entries + PROCESS_STATE], PROCESS_READY

    ; enable irqs
    mov edx, 0x1
    call config_irq

    ; enable interrupts
    sti

    mov rbx, 0xE9
    mov rcx, 1
    call config_port

    ; run init
    mov rsi, init_out
    mov rax, SYSCALL_RUN
    int 0x80

    ; idle (process 0)
@@: hlt
    jmp @b

;;;;;;;;;;;;;;;;;;;;;;
;; SYSCALLS ;;
;;;;;;;;;;;;;;;;;;;;;;

run:

; in:
;   - rsi: file name of binary to run
;   - rbx..r8: optional startup args for the new process

    ; save startup args across load_binary
    push r8
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx

    call load_binary
    jc @f

    mov r11, rdx ; preserve entry point

    ; restore args
    mov rbx, [rsp + 0]
    mov rcx, [rsp + 8]
    mov r8, [rsp + 16]
    mov rsi, [rsp + 24]
    mov rdi, [rsp + 32]
    mov r9, [rsp + 40]
    mov rdx, r11

    ; run
    call new_process

@@: add rsp, 48
    ret

exit:

; in:
;   - r10: current process

    cli
    mov qword [r10 + PROCESS_STATE], PROCESS_DEAD
    jmp switch_task

malloc:

; in:
;   - r10: process to alloc from
;   - rcx: bytes to alloc
; out:
;   - rax: 16-byte aligned ptr to alloced memory

    test rcx, rcx
    jz @f

    mov r8, [r10 + PROCESS_HEAP]
    add r8, 15
    and r8, -16 ; r8 = aligned start
    mov r9, r8
    add r9, rcx ; r9 = new heap top
    jc @f
    cmp r9, [r10 + PROCESS_HEAPEND]
    ja @f

    mov [r10 + PROCESS_HEAP], r9
    mov rax, r8
    ret

@@: xor eax, eax
    ret

free:
    ret

config_port:

; in:
;   - rbx: port number
;   - rcx: 0 = disable, 1 = enable

    movzx eax, bx
    test ecx, ecx
    jz @f

    btr [tss.io], eax ; allow
    xor eax, eax
    ret

@@: bts [tss.io], eax ; deny
    xor eax, eax
    ret

poll:

; in:
;   - r10: current process
; out:
;   - rax: pending flags, cleared on read

    xor eax, eax
    xchg [r10 + PROCESS_FLAGS], rax
    ret

read:

; in:
;   - rsi: filename to read
; out:
;   - rax: ptr to read data (0 on error)
;   - rbx: size of read data

    push rcx

    ; alloc 64k
    mov rcx, 0x10000
    mov rax, SYSCALL_MALLOC
    int 0x80
    test rax, rax
    jz .error
    mov rdi, rax
    push rax

    ; read file into alloced memory
    call fat16_read_file
    jc .read_fail

    mov rbx, rax ; file size
    pop rax
    pop rcx
    ret

    .read_fail:
        add rsp, 8 ; drop saved ptr
    .error:
        pop rcx
        xor rax, rax
        ret

;;;;;;;;;;;;;;
;; HANDLERS ;;
;;;;;;;;;;;;;;

keyboard_handler:
    ; scancode is left in the controller for userspace to read
    lea rbx, [processes.entries]
    mov ecx, PROCESSES_MAX

    ; set keyboard input recieved flag for all ready processes
@@: cmp qword [rbx + PROCESS_STATE], PROCESS_READY
    jne .skip
    lock or qword [rbx + PROCESS_FLAGS], PROCESS_FLAG_KEY
    .skip:
        add rbx, PROCESS_SIZE
        dec ecx
        jnz @b
        
    ret

timer_handler:
    jmp switch_task ; preempt on every tick

syscall_handler:

; in:
;   - rax: syscall number

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

    ; load args from the saved frame
    mov rbx, [rsp + 8]
    mov rcx, [rsp + 16]
    mov rdx, [rsp + 24]
    mov rsi, [rsp + 32]
    mov rdi, [rsp + 40]

    ; handlers get the caller's process in r10
    mov r10, [processes.current]
    imul r10, r10, PROCESS_SIZE
    add r10, processes.entries
    call r11

    mov [rsp + 0], rax
    mov [rsp + 8], rbx
    mov [rsp + 16], rcx
    mov [rsp + 24], rdx
    mov [rsp + 32], rsi
    mov [rsp + 40], rdi

    ; return to ring3 or ring0 depending on the saved cs
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

switch_task:
    ; find next ready process
    mov r10, [processes.current]
    imul r10, r10, PROCESS_SIZE
    add r10, processes.entries
    call schedule
    cmp rax, -1
    je @f
    cmp rax, r10 ; same process, nothing to do
    je @f

    ; switch task
    mov [r10 + PROCESS_KRSP], rsp
    mov rsp, [rax + PROCESS_KRSP]
    mov rcx, [rax + PROCESS_CR3]
    mov cr3, rcx
    mov rcx, [rax + PROCESS_RSP0]
    mov [tss.rsp0], rcx
@@: ret

schedule:

; out:
;   - rax: ptr to next ready process

    mov r8, [processes.current]
    mov r9d, PROCESSES_MAX

    .next:
        inc r8
        cmp r8, PROCESSES_MAX
        jb @f
        xor r8d, r8d ; wrap around

@@:     imul rdx, r8, PROCESS_SIZE
        lea rax, [processes.entries + rdx]
        cmp qword [rax + PROCESS_STATE], PROCESS_READY
        je .found
        dec r9d
        jnz .next

    mov rax, -1
    ret

    .found:
        mov [processes.current], r8
        ret

config_irq:

; in:
;   - edx/rdx: irq number

    push rdx

    ; get apic id via cpuid into ebx
    mov eax, 1
    cpuid
    shr ebx, 24

    pop rdx

    ; index = IOAPIC_REDTBL_BASE + (irq * 2)
    lea ecx, [IOAPIC_REDTBL_BASE + (edx*2)]

    mov r8d, IOAPIC_REG_INDEX
    mov r9d, IOAPIC_REG_DATA

    ; write low part (vector = irq + 32)
    lea eax, [edx + 32]
    and eax, 0xFF
    mov dword [r8], ecx
    mov dword [r9], eax

    ; write high part
    mov eax, ebx
    shl eax, 24
    inc ecx
    mov dword [r8], ecx
    mov dword [r9], eax

    ret

load_binary:

; in:
;   - rsi: file name to load
; out:
;   - cf: set if error
;   - rdx: entry point of loaded binary

    push rbx
    push rcx

    ; alloc 64k for binary
    mov rcx, 0x10000
    mov rax, SYSCALL_MALLOC
    int 0x80
    test rax, rax
    jz .error

    push rax ; save ptr

    ; read file
    mov rax, SYSCALL_READ
    int 0x80
    test rax, rax
    jnz @f
    add rsp, 8 ; drop saved ptr
    jmp .error

    ; reloc elf binary from scratch (rax) into allocated memory (rbx)
@@: pop rbx
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

new_process:

; in:
;   - rdx: user entry point
;   - rbx: initial user rbx
;   - rcx: initial user rcx
;   - r8:  initial user rdx
;   - rsi: initial user rsi
;   - rdi: initial user rdi
;   - r9:  initial user r8
; out:
;   - rax: ptr to process

    push rbx
    push rcx
    push rsi
    push rdi
    push r10
    push r8
    push r9

    ; claim a free slot
    lea r10, [processes.entries + PROCESS_SIZE]
    mov r8d, 1 ; r8 = slot index
@@: xor eax, eax ; expect dead slot
    mov ecx, PROCESS_ALIVE ; claimed but not yet schedulable
    lock cmpxchg [r10 + PROCESS_STATE], rcx ; atomic claim
    je @f
    add r10, PROCESS_SIZE
    inc r8d
    cmp r8d, PROCESSES_MAX
    jb @b
    jmp .none
@@:

    ; heap region for this slot
    imul rax, r8, PROCESS_HEAP_SIZE
    add rax, HEAP_BASE
    mov [r10 + PROCESS_HEAP], rax
    add rax, PROCESS_HEAP_SIZE
    mov [r10 + PROCESS_HEAPEND], rax
    mov qword [r10 + PROCESS_FLAGS], 0

    ; private pml4: 4k-aligned copy of the kernel one
    mov ecx, 0x2000
    call malloc
    test rax, rax
    jz .error
    add rax, 0xFFF
    and rax, -0x1000
    mov [r10 + PROCESS_CR3], rax
    mov rdi, rax
    mov rsi, pml4
    mov ecx, 512
    rep movsq

    ; kernel stack (rsp0)
    mov ecx, 0x4000
    call malloc
    test rax, rax
    jz .error
    add rax, 0x4000
    mov [r10 + PROCESS_RSP0], rax

    ; user stack
    mov ecx, 0x4000
    call malloc
    test rax, rax
    jz .error
    add rax, 0x4000
    mov rsi, rax

    ; create fake stack frame for iretq to land in ring3
    mov rdi, [r10 + PROCESS_RSP0]
    mov qword [rdi - 8], 0x1B ; ss
    mov [rdi - 16], rsi ; rsp
    mov qword [rdi - 24], 0x202 ; rflags
    mov qword [rdi - 32], 0x23 ; cs
    mov [rdi - 40], rdx ; rip
    mov qword [rdi - 48], 0 ; error code
    mov qword [rdi - 56], 0x20 ; vector
    mov rax, exception_handler.eoi
    mov [rdi - 184], rax
    lea rax, [rdi - 184]
    mov [r10 + PROCESS_KRSP], rax

    ; zero the saved gprs
    lea rdi, [rdi - 176]
    xor eax, eax
    mov ecx, 15
    rep stosq

    ; seed user registers 
    mov rax, [r10 + PROCESS_RSP0]
    mov r11, [rsp + 48] ; saved rbx
    mov [rax - 168], r11 ; user rbx
    mov r11, [rsp + 40] ; saved rcx
    mov [rax - 160], r11 ; user rcx
    mov r11, [rsp + 8] ; saved r8
    mov [rax - 152], r11 ; user rdx
    mov r11, [rsp + 32] ; saved rsi
    mov [rax - 144], r11 ; user rsi
    mov r11, [rsp + 24] ; saved rdi
    mov [rax - 136], r11 ; user rdi
    mov r11, [rsp + 0] ; saved r9
    mov [rax - 120], r11 ; user r8

    mov qword [r10 + PROCESS_STATE], PROCESS_READY
    mov rax, r10
    jmp .done

    .error:
        mov qword [r10 + PROCESS_STATE], PROCESS_DEAD ; release claimed slot
    .none:
        xor eax, eax
    .done:
        pop r9
        pop r8
        pop r10
        pop rdi
        pop rsi
        pop rcx
        pop rbx
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
init_out: mk8.3 "INIT", "OUT"

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
align 16
processes:
    .current: dq -1
    .entries: rb (PROCESS_SIZE*PROCESSES_MAX)
lapic: dq 0

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