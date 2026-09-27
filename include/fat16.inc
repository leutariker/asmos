macro mk8.3 name, ext {
    local .start
    .start: db name
    times 8 - ($ - .start) db ' '
    db ext
}

FAT16_BPB = 0x7C00
FAT16_SCRATCH = 0x7A00

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

    if IS_X64
        push rbx
        push rcx

        mov ax, [FAT16_BPB + FAT16_BPB_RESERVED_SECTORS]
        xor cx, cx
        mov cl, [FAT16_BPB + FAT16_BPB_NUM_FATS]
        xor bx, bx
        mov bx, [FAT16_BPB + FAT16_BPB_SECTORS_PER_FAT]

    @@: add ax, bx
        dec cx
        jnz @b

        pop rcx
        pop rbx
    else
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
    end if
    ret

fat16_get_data_start:

; out:
;   - ax: lba of data area start

    if IS_X64
        push rbx
        push rcx
        push rdx

        call fat16_get_root_dir_start
        mov bx, ax

        mov ax, [FAT16_BPB + FAT16_BPB_ROOT_ENTRIES]
        shl ax, 5
        add ax, [FAT16_BPB + FAT16_BPB_BYTES_PER_SECTOR]
        dec ax
        xor dx, dx
        div word [FAT16_BPB + FAT16_BPB_BYTES_PER_SECTOR]
        add ax, bx

        pop rdx
        pop rcx
        pop rbx
    else
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
    end if
    ret

fat16_find_file:

; in:
;   - esi/rsi: pointer to 11-byte filename
; out:
;   - ax: first cluster of the file
;   - ebx/rbx: file size in bytes
;   - cf: set if file was not found

    if IS_X64
        push rbx
        push rcx
        push rdx
        push rdi
    else
        push ebx
        push ecx
        push edx
        push edi
    end if

    call fat16_get_root_dir_start
    movzx ebx, ax

    movzx edx, word [FAT16_BPB + FAT16_BPB_ROOT_ENTRIES] ; edx = entries left to check
    .next_sector:
        mov eax, ebx
        if IS_X64
            mov rdi, FAT16_SCRATCH
        else
            mov edi, FAT16_SCRATCH
        end if
        mov cl, 1
        call ata_read
        inc ebx

    .next_entry:
        if IS_X64
            cmp byte [rdi], 0
        else
            cmp byte [edi], 0
        end if
        je .error ; no more entries in the directory

        if IS_X64
            cmp byte [rdi], 0xE5
        else
            cmp byte [edi], 0xE5
        end if
        je .skip ; deleted entry

        if IS_X64
            push rdi
            push rsi
        else
            push edi
            push esi
        end if
        mov ecx, 11
        repe cmpsb
        if IS_X64
            pop rsi
            pop rdi
        else
            pop esi
            pop edi
        end if
        je .found

    .skip:
        if IS_X64
            add rdi, 32
        else
            add edi, 32
        end if
        dec edx
        jz .error ; ran out of entries
        if IS_X64
            test rdi, 0x1FF
        else
            test edi, 0x1FF
        end if
        jnz .next_entry
        jmp .next_sector

    .found:
        if IS_X64
            movzx eax, word [rdi + 26] ; get first cluster
            mov ebx, dword [rdi + 28]  ; get 32-bit file size
        else
            movzx eax, word [edi + 26] ; get first cluster
            mov ebx, dword [edi + 28]  ; get 32-bit file size
        end if
        if IS_X64
            mov [rsp + 24], rbx ; overwrite saved rbx so it pops to caller
        else
            mov [esp + 12], ebx ; overwrite saved ebx so it pops to caller
        end if
        clc
        jmp .exit

    .error:
        stc

    .exit:
        if IS_X64
            pop rdi
            pop rdx
            pop rcx
            pop rbx
        else
            pop edi
            pop edx
            pop ecx
            pop ebx
        end if
        ret

fat16_get_next_cluster:

; in:
;   - ax: cluster number
; out:
;   - ax: next cluster number

    if IS_X64
        push rbx
        push rcx
        push rdx
        push rdi
    else
        push ebx
        push ecx
        push edx
        push edi
    end if

    movzx ebx, ax
    shl ebx, 1 ; ebx = byte offset of this cluster's entry within the fat table

    movzx ecx, word [FAT16_BPB + FAT16_BPB_BYTES_PER_SECTOR]
    mov eax, ebx
    xor edx, edx
    div ecx ; eax = sector offset within the fat table, edx = byte offset within that sector
    mov ebx, edx ; ebx = byte offset within the sector

    add ax, [FAT16_BPB + FAT16_BPB_RESERVED_SECTORS] ; ax = lba of the fat sector containing this entry

    if IS_X64
        mov rdi, FAT16_SCRATCH
    else
        mov edi, FAT16_SCRATCH
    end if
    mov cl, 1
    call ata_read

    if IS_X64
        movzx eax, word [FAT16_SCRATCH + rbx]
    else
        movzx eax, word [FAT16_SCRATCH + ebx]
    end if

    if IS_X64
        pop rdi
        pop rdx
        pop rcx
        pop rbx
    else
        pop edi
        pop edx
        pop ecx
        pop ebx
    end if
    ret

fat16_read_cluster:

; in:
;   - ax: cluster number
;   - edi/rdi: pointer to buffer to read into

    if IS_X64
        push rax
        push rcx
        push rdx
        push rdi
    else
        push eax
        push ecx
        push edx
        push edi
    end if

    movzx ecx, ax
    sub ecx, 2
    movzx edx, byte [FAT16_BPB + FAT16_BPB_SECTORS_PER_CLUSTER]

    call fat16_get_data_start
    movzx eax, ax
    imul ecx, edx
    if IS_X64
        add rax, rcx
    else
        add eax, ecx
    end if

    mov cl, [FAT16_BPB + FAT16_BPB_SECTORS_PER_CLUSTER]
    call ata_read

    if IS_X64
        pop rdi
        pop rdx
        pop rcx
        pop rax
    else
        pop edi
        pop edx
        pop ecx
        pop eax
    end if
    ret

fat16_read_file:

; in:
;   - esi/rsi: pointer to 11-byte filename
;   - edi/rdi: pointer to buffer to read the file into
; out:
;   - eax/rax: size of the file in bytes
;   - cf: set if the file was not found

    if IS_X64
        push rbx
        push rax
        push rcx
        push rdx
    else
        push ebx
        push eax
        push ecx
        push edx
    end if

    call fat16_find_file
    jc .exit

    ; fat16_find_file returned the size in ebx/rbx
    ; overwrite the pushed eax/rax so it gets popped to the caller on exit
    if IS_X64
        mov [rsp + 16], rbx
    else
        mov [esp + 8], ebx
    end if

    movzx ecx, word [FAT16_BPB + FAT16_BPB_BYTES_PER_SECTOR]
    movzx edx, byte [FAT16_BPB + FAT16_BPB_SECTORS_PER_CLUSTER]
    imul ecx, edx ; ecx = bytes per cluster

@@: call fat16_read_cluster
    if IS_X64
        add rdi, rcx
    else
        add edi, ecx
    end if
    call fat16_get_next_cluster
    cmp ax, 0xFFF8 ; end of cluster
    jb @b

    clc

    .exit:
        if IS_X64
            pop rdx
            pop rcx
            pop rax
            pop rbx
        else
            pop edx
            pop ecx
            pop eax
            pop ebx
        end if
        ret