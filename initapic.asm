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

format ELF executable 3 at 0x1000
use32
entry start
segment readable executable writable

start:

; in:
;   - eax: pointer to lapic storage location in stage3

    mov ebx, eax  ; save pointer to stage3's lapic variable

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
    mov [ebx], eax  ; store to stage3's lapic pointer
    mov esi, eax

    ; init lapic sivr
    mov eax, [esi + APIC_REG_SIVR]
    or eax, APIC_SIVR_ENABLE or APIC_SIVR_VECTOR
    mov [esi + APIC_REG_SIVR], eax

    ; init apic timer
    mov dword [esi + APIC_REG_TIMER_DIV], 0x3 ; divide by 16
    mov dword [esi + APIC_REG_LVT_TIMER], 0x20 or (1 shl 17) ; periodic timer
    mov dword [esi + APIC_REG_TIMER_INIT], 0x1000000 ; initial count

    ; init keyboard irq
    mov edx, 1
    call init_irq

    ; return lapic address in eax
    mov eax, [ebx]  ; load from stage3's lapic pointer
    ret

init_irq:

; in:
;   - edx: irq number

    push edx

    ; get apic id via cpuid into ebx
    mov eax, 1
    cpuid
    shr ebx, 24

    pop edx
    
    ; index = IOAPIC_REDTBL_BASE + (irq * 2)
    lea ecx, [IOAPIC_REDTBL_BASE + (edx*2)]

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