format binary
org 0x7C00
use16

bpb:
    .entry:
        jmp short start
        nop
    .oem_id: times 8 db 0
    .bytes_per_sector: dw 0
    .sectors_per_cluster: db 0
    .reserved_sectors: dw 0
    .num_fats: db 0
    .root_entries: dw 0
    .total_sectors_16: dw 0
    .media_descriptor: db 0
    .sectors_per_fat: dw 0
    .sectors_per_track: dw 0
    .num_heads: dw 0
    .hidden_sectors: dd 0
    .total_sectors_32: dd 0
    .drive_number: db 0
    .reserved: db 0
    .boot_signature: db 0
    .volume_id: dd 0
    .volume_label: times 11 db 0
    .filesystem_type: times 8 db 0

stage2:
    .size: db 0x10
    .reserved: db 0
    .count: dw 0
    .buffer: dq 0x8000
    .lba: dq 0

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov gs, ax
    mov fs, ax
    mov bp, ax
    mov sp, 0x7C00

    mov dl, [bpb.drive_number]
    call has_edd?
    jc reboot

    mov ah, 0x42
    mov si, stage2
    mov dl, [bpb.drive_number]
    int 0x13
    test al, al
    jc reboot

    jmp 0x8000
    jmp reboot

has_edd?:

; in:
;   - dl: disk number

	mov ah, 0x41
	mov bx, 0x55aa
	int 0x13
	jc .error
	cmp bx, 0xaa55
	jne .error
	test cx, 1
	jz .error

    clc
    ret

    .error:
        stc
        ret

include "include/reboot.inc"

times (510 - ($ - $$)) db 0
dw 0xAA55