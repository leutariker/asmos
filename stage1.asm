format binary
org 0x7C00
use16

jmp short start
nop

bpb:
    .oem_id: times 11 db 0
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

start:
    cli

    mov [bpb.drive_number], dl

    mov al, 'A'
    mov ah, 0x0E
    int 0x10

    jmp $

times (510 - ($ - $$)) db 0
dw 0xAA55