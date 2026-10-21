format binary
org 0x8000

BPB = 0x7C00
BPB_SECTORS_PER_CLUSTER = 13
BPB_RESERVED_SECTORS = 14
BPB_NUM_FATS = 16
BPB_ROOT_ENTRIES = 17
BPB_SECTORS_PER_FAT = 22
SCRATCH = 0x7A00
FILE_BUFFER = 0x10000

use16
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov gs, ax
    mov fs, ax
    xor bp, bp
    mov sp, 0x8000

    lgdt [gdtr]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x10:main

use32
main:
    mov ax, 0x08
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov gs, ax
    mov fs, ax
    cld

    ; root_lba = reserved + fats * sectors_per_fat
    movzx eax, byte [BPB + BPB_NUM_FATS]
    movzx ecx, word [BPB + BPB_SECTORS_PER_FAT]
    imul eax, ecx
    movzx ecx, word [BPB + BPB_RESERVED_SECTORS]
    add eax, ecx
    mov [root_lba], eax

    ; data_lba = root_lba + root directory size in sectors (16 entries per sector)
    movzx ecx, word [BPB + BPB_ROOT_ENTRIES]
    add ecx, 15
    shr ecx, 4
    add eax, ecx
    mov [data_lba], eax

    mov esi, stage3
    mov edi, FILE_BUFFER
    call read_file
    jc reboot

    mov eax, FILE_BUFFER
    call load_elf
    jc reboot

    jmp eax

reboot:
    cli
@@: in al, 0x64
    test al, 0x02
    jnz @b
    mov al, 0xFE
    out 0x64, al
    hlt
    jmp @b

read_sectors:

; in:
;   - eax = lba
;   - ecx = sector count
;   - edi = buffer

    pushad

    mov ebx, eax

    mov edx, 0x1F6
    shr eax, 24
    or al, 0xE0
    out dx, al

    mov edx, 0x1F2
    mov al, cl
    out dx, al

    inc edx
    mov al, bl
    out dx, al

    inc edx
    mov al, bh
    out dx, al

    inc edx
    shr ebx, 16
    mov al, bl
    out dx, al

    add edx, 2
    mov al, 0x20
    out dx, al

@@: in al, dx
    and al, 0x88 ; BSY | DRQ
    cmp al, 0x08
    jne @b

    push ecx
    push edx
    mov ecx, 256
    mov edx, 0x1F0
    rep insw
    pop edx
    pop ecx
    loop @b

    popad
    ret

read_file:

; in:
;   - esi = 11-byte 8.3 name
;   - edi = read buffer

    mov ebp, edi
    mov eax, [root_lba]
    movzx edx, word [BPB + BPB_ROOT_ENTRIES]

    .next_sector:
        mov edi, SCRATCH
        mov ecx, 1
        call read_sectors
        inc eax

    .next_entry:
        cmp byte [edi], 0
        je .fail
        cmp byte [edi], 0xE5
        je .skip

        push esi
        push edi
        mov ecx, 11
        repe cmpsb
        pop edi
        pop esi
        je .found

    .skip:
        add edi, 32
        dec edx
        jz .fail
        cmp edi, SCRATCH + 512
        jne .next_entry
        jmp .next_sector

    .found:
        movzx ebx, word [edi + 26] ; first cluster
        mov edi, ebp
        movzx esi, byte [BPB + BPB_SECTORS_PER_CLUSTER]

    .cluster:
        lea eax, [ebx - 2]
        imul eax, esi
        add eax, [data_lba]
        mov ecx, esi
        call read_sectors

        mov eax, esi
        shl eax, 9
        add edi, eax

        ; fat16 entries are 2 bytes, so 256 per sector
        mov eax, ebx
        shr eax, 8
        movzx ecx, word [BPB + BPB_RESERVED_SECTORS]
        add eax, ecx
        push edi
        mov edi, SCRATCH
        mov ecx, 1
        call read_sectors
        pop edi

        movzx eax, bl
        movzx ebx, word [SCRATCH + eax * 2]
        cmp ebx, 0xFFF8
        jb .cluster

        clc
        ret

    .fail:
        stc
        ret

load_elf:

; in:
;   - eax = elf64 image
; out:
;   - eax = entry point

    cmp dword [eax], 0x464C457F
    jne .fail
    cmp byte [eax + 4], 2 ; ELFCLASS64
    jne .fail
    cmp word [eax + 16], 2 ; ET_EXEC
    jne .fail
    cmp word [eax + 18], 62 ; EM_X86_64
    jne .fail

    mov ebx, eax
    mov edx, [ebx + 32] ; e_phoff
    add edx, ebx
    movzx ebp, word [ebx + 56] ; e_phnum

    .next_phdr:
        test ebp, ebp
        jz .done
        cmp dword [edx], 1 ; PT_LOAD
        jne .skip

        mov ecx, [edx + 32] ; p_filesz
        mov eax, [edx + 40] ; p_memsz
        sub eax, ecx
        jb .fail
        mov esi, [edx + 8] ; p_offset
        add esi, ebx
        mov edi, [edx + 16] ; p_vaddr
        rep movsb
        mov ecx, eax
        xor eax, eax
        rep stosb

    .skip:
        movzx eax, word [ebx + 54] ; e_phentsize
        add edx, eax
        dec ebp
        jmp .next_phdr

    .done:
        mov eax, [ebx + 24] ; e_entry
        clc
        ret

    .fail:
        stc
        ret

gdt:
    dq 0x0000000000000000
    dq 0x00CF92000000FFFF
    dq 0x00CF9A000000FFFF
gdtr:
    dw gdtr - gdt - 1
    dd gdt

stage3 db "STAGE3  OUT"
root_lba dd 0
data_lba dd 0