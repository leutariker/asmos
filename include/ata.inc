ata_read:

; in:
;   - eax/rax: lba to read from
;   - cl: number of sectors to read
;   - edi/rdi: pointer to buffer to read into

    if IS_X64
        pushfq
        and eax, 0x0FFFFFFF
        push rax
        push rbx
        push rcx
        push rdx
        push rdi
    else
        pushfd
        and eax, 0x0FFFFFFF
        push eax
        push ebx
        push ecx
        push edx
        push edi
    end if

    ; save lba
    mov ebx, eax

    ; set which drive to read from
    mov edx, 0x01F6
    shr eax, 24
    or al, 11100000b
    out dx, al

    ; set how many sectors to read
    mov edx, 0x01F2
    mov al, cl
    out dx, al

    ; set at which lba to start reading from (bit 0-7)
    mov edx, 0x1F3
    mov eax, ebx
    out dx, al

    ; set at which lba to start reading from (bit 8-15)
    mov edx, 0x1F4
    mov eax, ebx
    shr eax, 8
    out dx, al

    ; set at which lba to start reading from (bit 16-23)
    mov edx, 0x1F5
    mov eax, ebx
    shr eax, 16
    out dx, al

    ; send read command
    mov edx, 0x1F7
    mov al, 0x20
    out dx, al

    ; poll until drive is ready
@@: in al, dx
    test al, 8
    jz @b

    ; read into edi/rdi
    mov eax, 256 ; read 256 words (1 sector) at time
    xor bx, bx
    mov bl, cl ; read cl sectors total
    mul bx
    mov ecx, eax
    mov edx, 0x1F0
    rep insw

    if IS_X64
        pop rdi
        pop rdx
        pop rcx
        pop rbx
        pop rax
        popfq
    else
        pop edi
        pop edx
        pop ecx
        pop ebx
        pop eax
        popfd
    end if
    ret