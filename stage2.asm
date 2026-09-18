format binary
org 0x8000

use16
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov gs, ax
    mov fs, ax
    mov bp, ax
    mov sp, 0x8000

    lgdt [gdtr]

    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp 0x10:main

@@: hlt
    jmp @b

use32
main:
    cli
    mov ax, 0x08
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov gs, ax
    mov fs, ax

    mov esi, STAGE3_FILENAME
    mov edi, 0x10000
    call fat16_read_file
    jc reboot

    mov eax, 0x10000
    call elf32_load_file
    jc reboot

    jmp eax
    jmp reboot

reboot:
    cli
@@: in al, 0x64
    test al, 0x02
    jnz @b
    mov al, 0xFE
    out 0x64, al
    hlt

gdt:
    dq 0x0000000000000000
    dq 0x00CF92000000FFFF
    dq 0x00CF9A000000FFFF
gdtr:
    dw gdtr - gdt - 1
    dd gdt

STAGE3_FILENAME db "STAGE3  OUT"

include "include/ata.inc"
include "include/fat16.inc"
include "include/elf32.inc"