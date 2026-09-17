FAT16_BPB = 0x7C00

FAT16_BPB_ENTRY = 0
FAT16_BPB_OEM_ID = FAT16_BPB_ENTRY + 3
FAT16_BPB_BYTES_PER_SECTOR = FAT16_BPB_OEM_ID + 8
FAT16_BPB_SECTORS_PER_CLUSTER = FAT16_BPB_BYTES_PER_SECTOR + 2
FAT16_BPB_RESERVED_SECTORS = FAT16_BPB_SECTORS_PER_CLUSTER + 1
FAT16_BPB_NUM_FATS = FAT16_BPB_RESERVED_SECTORS + 2
FAT16_BPB_ROOT_ENTRIES = FAT16_BPB_NUM_FATS + 1
FAT16_BPB_TOTAL_SECTORS_16 = FAT16_BPB_ROOT_ENTRIES + 2
FAT16_BPB_MEDIA_DESCRIPTOR = FAT16_BPB_TOTAL_SECTORS_16 + 2
FAT16_BPB_SECTORS_PER_FAT = FAT16_BPB_MEDIA_DESCRIPTOR + 1
FAT16_BPB_SECTORS_PER_TRACK = FAT16_BPB_SECTORS_PER_FAT + 2
FAT16_BPB_NUM_HEADS = FAT16_BPB_SECTORS_PER_TRACK + 2
FAT16_BPB_HIDDEN_SECTORS = FAT16_BPB_NUM_HEADS + 2
FAT16_BPB_TOTAL_SECTORS_32 = FAT16_BPB_HIDDEN_SECTORS + 4
FAT16_BPB_DRIVE_NUMBER = FAT16_BPB_TOTAL_SECTORS_32 + 4
FAT16_BPB_RESERVED = FAT16_BPB_DRIVE_NUMBER + 1
FAT16_BPB_BOOT_SIGNATURE = FAT16_BPB_RESERVED + 1
FAT16_BPB_VOLUME_ID = FAT16_BPB_BOOT_SIGNATURE + 1
FAT16_BPB_VOLUME_LABEL = FAT16_BPB_VOLUME_ID + 4
FAT16_BPB_FILESYSTEM_TYPE = FAT16_BPB_VOLUME_LABEL + 11

fat16_get_fat_table:

; out:
;   - ax: lba of fat table start

    mov ax, [FAT16_BPB + FAT16_BPB_RESERVED_SECTORS]
    ret

fat16_get_root_dir_start:

; out:
;   - ax: lba of root directory start

    push bx
    push cx

    mov ax, [FAT16_BPB + FAT16_BPB_RESERVED_SECTORS]
    xor cx, cx
    mov cl, [FAT16_BPB + FAT16_BPB_NUM_FATS]
    xor bx, bx
    mov bx, [FAT16_BPB + FAT16_BPB_SECTORS_PER_FAT]

@@: add ax, bx
    dec cx
    jnz @b

    pop cx
    pop bx
    ret

fat16_get_data_start:

; out:
;   - ax: lba of data area start

    push bx
    push cx
    push dx

    call fat16_get_root_dir_start
    mov bx, ax

    mov ax, [FAT16_BPB + FAT16_BPB_ROOT_ENTRIES]
    shl ax, 5
    add ax, [FAT16_BPB + FAT16_BPB_BYTES_PER_SECTOR]
    dec ax
    xor dx, dx
    div word [FAT16_BPB + FAT16_BPB_BYTES_PER_SECTOR]
    add ax, bx

    pop dx
    pop cx
    pop bx
    ret

fat16_get_next_cluster:

; in:
;   - ax: cluster number
; out:
;   - ax: next cluster number

    push bx
    push ecx

    mov bx, ax
    mov ax, [FAT16_BPB + FAT16_BPB_RESERVED_SECTORS]
    movzx ecx, bx
    shl ecx, 1
    add cx, ax
    mov ax, [ecx]

    pop ecx
    pop bx
    ret

fat16_read_cluster:

; in:
;   - ax: cluster number
;   - edi: pointer to buffer to read into

    push eax
    push ecx
    push edx
    push edi

    movzx ecx, ax
    sub ecx, 2
    movzx edx, byte [FAT16_BPB + FAT16_BPB_SECTORS_PER_CLUSTER]

    call fat16_get_data_start
    movzx eax, ax
    imul ecx, edx
    add eax, ecx

    mov cl, [FAT16_BPB + FAT16_BPB_SECTORS_PER_CLUSTER]
    call ata_read

    pop edi
    pop edx
    pop ecx
    pop eax
    ret