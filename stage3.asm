PIC1 = 0x20
PIC2 = 0xA0
PIC1_DATA = PIC1 + 1
PIC2_DATA = PIC2 + 1
PIC_EOI = 0x20

APIC_IA32_BASE_MSR = 0x1B
APIC_IA32_BASE_MSR_ENABLE = 0x800
APIC_REG_SIVR = 0xF0
APIC_REG_EOI = 0xB0
APIC_REG_ID = 0x20
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

    ; disable the 8259 pic
    mov al, 0xFF
    out PIC1, al
    out PIC2, al

    ; enable apic
    mov ecx, APIC_IA32_BASE_MSR
    rdmsr
    or eax, APIC_IA32_BASE_MSR_ENABLE
    wrmsr

    ; store lapic base address
    mov ecx, APIC_IA32_BASE_MSR
    rdmsr
    and eax, 0xFFFFF000
    mov [lapic], eax
    mov esi, eax

    ; init lapic sivr
    mov eax, [esi + APIC_REG_SIVR]
    or eax, APIC_SIVR_ENABLE or APIC_SIVR_VECTOR
    mov [esi + APIC_REG_SIVR], eax

    ; init apic timer
    mov dword [esi + APIC_REG_TIMER_DIV], 0x3 ; divide by 16
    mov dword [esi + APIC_REG_LVT_TIMER], 0x20 or (1 shl 17) ; periodic timer
    mov dword [esi + APIC_REG_TIMER_INIT], 0x1000000 ; initial count

    ; enable interrupts
    mov edx, 0
    call init_irq ; timer

    ; load idt
    lidt [idtr]

    sti
@@: hlt
    jmp @b

init_irq:

; in:
;   - edx: irq number

    ; get apic id via cpuid into ebx
    mov eax, 1
    cpuid
    shr ebx, 24
    
    ; index = IOAPIC_REDTBL_BASE + (irq * 2)
    lea ecx, [IOAPIC_REDTBL_BASE + edx*2]

    ; write low part (vector = irq + 32)
    lea eax, [edx + 32]
    and eax, 0xFF
    mov dword [IOAPIC_REG_INDEX], ecx
    mov dword [IOAPIC_REG_DATA], eax

    ; write high part    
    mov eax, ebx
    shl eax, 24
    inc ecx
    mov dword [IOAPIC_REG_INDEX], ecx
    mov dword [IOAPIC_REG_DATA], eax
    
    ret

exception_handler:
    pop eax ; exception number
    
    ; check if this exception pushed an error code
    mov ecx, 1
    mov cl, al
    shl ecx, cl
    test ecx, 0x227D00 ; bitmask for exceptions 8,10,11,12,13,14,17,21
    jnz .error
    
    cmp eax, 31
    jg .irq

    iret

    .error:
        cli
        pop ebx ; pop error code

        mov esi, error_messages
        mov ecx, eax
        shl ecx, 5 ; 32 bytes per message
        add esi, ecx
        call debug

@@:     cli
        hlt
        jmp @b

    .irq:
        ; send eoi to apic
        mov eax, [lapic]
        mov dword [eax + APIC_REG_EOI], 0
        iret

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
@@:     push n
        jmp exception_handler
        times (16 - ($ - @b)) db 0
    }

segment readable
idt:
    rept 256 n:0 {
        dw ((idt_stubs + (16 * n)) and 0xFFFF) ; isr low
        dw 0x10 ; cs
        db 0 ; reserved
        db 0x86 ; attr
        dw ((idt_stubs + (16 * n)) shr 16) ; isr high
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

segment readable writable
lapic: dd 0

stack_btm: 
rb 16384
stack_top: