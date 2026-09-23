ELF64_TYPE_NONE = 0
ELF64_TYPE_REL = 1
ELF64_TYPE_EXEC = 2

ELF64_SHT_TYPE_NULL = 0
ELF64_SHT_TYPE_PROGBITS = 1
ELF64_SHT_TYPE_SYMTAB = 2
ELF64_SHT_TYPE_STRTAB = 3
ELF64_SHT_TYPE_RELA = 4
ELF64_SHT_TYPE_NOBITS = 8
ELF64_SHT_TYPE_REL = 9

ELF64_SHT_ATTR_WRITE = 0
ELF64_SHT_ATTR_ALLOC = 1

ELF64_RTTYPE_NONE = 0
ELF64_RTTYPE_64 = 1
ELF64_RTTYPE_PC32 = 2

ELF64_PHTYPE_NULL = 0
ELF64_PHTYPE_LOAD = 1

ELF64_HEADER_IDENT = 0
ELF64_HEADER_TYPE = ELF64_HEADER_IDENT + 16
ELF64_HEADER_MACHINE = ELF64_HEADER_TYPE + 2
ELF64_HEADER_VERSION = ELF64_HEADER_MACHINE + 2
ELF64_HEADER_ENTRY = ELF64_HEADER_VERSION + 4
ELF64_HEADER_PHOFF = ELF64_HEADER_ENTRY + 8
ELF64_HEADER_SHOFF = ELF64_HEADER_PHOFF + 8
ELF64_HEADER_FLAGS = ELF64_HEADER_SHOFF + 8
ELF64_HEADER_EHSIZE = ELF64_HEADER_FLAGS + 4
ELF64_HEADER_PHENTSIZE = ELF64_HEADER_EHSIZE + 2
ELF64_HEADER_PHNUM = ELF64_HEADER_PHENTSIZE + 2
ELF64_HEADER_SHENTSIZE = ELF64_HEADER_PHNUM + 2
ELF64_HEADER_SHNUM = ELF64_HEADER_SHENTSIZE + 2
ELF64_HEADER_SHSTRNDX = ELF64_HEADER_SHNUM + 2

ELF64_HEADER_IDENT_MAGIC = 0
ELF64_HEADER_IDENT_CLASS = 4
ELF64_HEADER_IDENT_DATA = 5
ELF64_HEADER_IDENT_VERSION = 6
ELF64_HEADER_IDENT_OSABI = 7
ELF64_HEADER_IDENT_ABIVERSION = 8
ELF64_HEADER_IDENT_PAD = 9

ELF64_SHDR_NAME = 0
ELF64_SHDR_TYPE = ELF64_SHDR_NAME + 4
ELF64_SHDR_FLAGS = ELF64_SHDR_TYPE + 4
ELF64_SHDR_ADDR = ELF64_SHDR_FLAGS + 8
ELF64_SHDR_OFFSET = ELF64_SHDR_ADDR + 8
ELF64_SHDR_SIZE = ELF64_SHDR_OFFSET + 8
ELF64_SHDR_LINK = ELF64_SHDR_SIZE + 8
ELF64_SHDR_INFO = ELF64_SHDR_LINK + 4
ELF64_SHDR_ADDRALIGN = ELF64_SHDR_INFO + 4
ELF64_SHDR_ENTSIZE = ELF64_SHDR_ADDRALIGN + 8

ELF64_SYM_NAME = 0
ELF64_SYM_INFO = ELF64_SYM_NAME + 4
ELF64_SYM_OTHER = ELF64_SYM_INFO + 1
ELF64_SYM_SHNDX = ELF64_SYM_OTHER + 1
ELF64_SYM_VALUE = ELF64_SYM_SHNDX + 2
ELF64_SYM_SIZE = ELF64_SYM_VALUE + 8

ELF64_PHDR_TYPE = 0
ELF64_PHDR_FLAGS = ELF64_PHDR_TYPE + 4
ELF64_PHDR_OFFSET = ELF64_PHDR_FLAGS + 4
ELF64_PHDR_VADDR = ELF64_PHDR_OFFSET + 8
ELF64_PHDR_PADDR = ELF64_PHDR_VADDR + 8
ELF64_PHDR_FILESZ = ELF64_PHDR_PADDR + 8
ELF64_PHDR_MEMSZ = ELF64_PHDR_FILESZ + 8
ELF64_PHDR_ALIGN = ELF64_PHDR_MEMSZ + 8
ELF64_PHDR_SIZE = ELF64_PHDR_ALIGN + 8

elf64_is_file_supported?:

; in:
;   - eax/rax: ptr to elf64_header
; out:
;   - cf: 1 if not supported, 0 if supported

    if IS_X64
        test rax, rax
        jz @f

        cmp dword [rax + ELF64_HEADER_IDENT_MAGIC], 0x464C457F ; 0x7F, "ELF"
        jne @f

        cmp byte [rax + ELF64_HEADER_IDENT_CLASS], 2 ; 64-bit (ELFCLASS64)
        jne @f

        cmp byte [rax + ELF64_HEADER_IDENT_DATA], 1 ; little endian
        jne @f

        cmp word [rax + ELF64_HEADER_MACHINE], 62 ; x86-64 (EM_X86_64)
        jne @f

        cmp byte [rax + ELF64_HEADER_IDENT_VERSION], 1
        jne @f

        cmp word [rax + ELF64_HEADER_TYPE], 1 ; relocatable
        jb @f

        cmp word [rax + ELF64_HEADER_TYPE], 2 ; executable
        ja @f

        clc
        ret

        @@:
            stc
            ret
    else
        test eax, eax
        jz @f

        cmp dword [eax + ELF64_HEADER_IDENT_MAGIC], 0x464C457F ; 0x7F, "ELF"
        jne @f

        cmp byte [eax + ELF64_HEADER_IDENT_CLASS], 2 ; 64-bit (ELFCLASS64)
        jne @f

        cmp byte [eax + ELF64_HEADER_IDENT_DATA], 1 ; little endian
        jne @f

        cmp word [eax + ELF64_HEADER_MACHINE], 62 ; x86-64 (EM_X86_64)
        jne @f

        cmp byte [eax + ELF64_HEADER_IDENT_VERSION], 1
        jne @f

        cmp word [eax + ELF64_HEADER_TYPE], 1 ; relocatable
        jb @f

        cmp word [eax + ELF64_HEADER_TYPE], 2 ; executable
        ja @f

        clc
        ret

        @@:
            stc
            ret
    end if

elf64_load_segment:

; in:
;   - ebx/rbx: pointer to elf64 image in memory
;   - ecx/rcx: pointer to elf64 program header
;   - edx/rdx: relocation delta (target_base - preferred_base)
; out:
;   - cf: set if segment cannot be loaded

    if IS_X64
        push rax
        push rcx
        push rdx
        push rsi
        push rdi

        ; check memsz >= filesz
        mov rax, [rcx + ELF64_PHDR_FILESZ]
        cmp rax, [rcx + ELF64_PHDR_MEMSZ]
        ja .error

        ; copy segment from raw image to target memory address (p_vaddr + delta)
        mov rsi, [rcx + ELF64_PHDR_OFFSET]
        add rsi, rbx
        jc .error

        mov rdi, [rcx + ELF64_PHDR_VADDR]
        add rdi, rdx

        push rcx
        push rax
        mov rcx, rax
        rep movsb

        ; clear out remaining bss memory (memsz - filesz)
        pop rax
        pop rcx
        mov rdx, [rcx + ELF64_PHDR_MEMSZ]
        sub rdx, rax
        mov rcx, rdx
        xor eax, eax
        rep stosb

        clc
        jmp .exit

        .error:
            stc

        .exit:
            pop rdi
            pop rsi
            pop rdx
            pop rcx
            pop rax
            ret
    else
        push eax
        push ecx
        push edx
        push esi
        push edi

        ; check memsz >= filesz
        mov eax, dword [ecx + ELF64_PHDR_FILESZ]
        cmp eax, dword [ecx + ELF64_PHDR_MEMSZ]
        ja .error

        ; copy segment from raw image to target memory address (p_vaddr + delta)
        mov esi, dword [ecx + ELF64_PHDR_OFFSET]
        add esi, ebx
        jc .error

        mov edi, dword [ecx + ELF64_PHDR_VADDR]
        add edi, edx

        push ecx
        push eax
        mov ecx, eax
        rep movsb

        ; clear out remaining bss memory (memsz - filesz)
        pop eax
        pop ecx
        mov edx, dword [ecx + ELF64_PHDR_MEMSZ]
        sub edx, eax
        mov ecx, edx
        xor eax, eax
        rep stosb

        clc
        jmp .exit

        .error:
            stc

        .exit:
            pop edi
            pop esi
            pop edx
            pop ecx
            pop eax
            ret
    end if

elf64_load_phdrs:

; in:
;   - eax/rax: pointer to raw elf image
;   - ebx/rbx: target load address (0 = use default)
; out:
;   - eax/rax: rebased entry point
;   - cf: set if program headers cannot be loaded

    if IS_X64
        push rbx
        push rcx
        push rdx
        push rsi
        push rdi

        mov rsi, rax

        ; check phdr size
        movzx ecx, word [rsi + ELF64_HEADER_PHENTSIZE]
        cmp ecx, ELF64_PHDR_SIZE
        jb .error

        ; check phdr count
        movzx edx, word [rsi + ELF64_HEADER_PHNUM]
        test edx, edx
        jz .error

        ; find first pt_load_phdr to get preferred load base address
        push rdx
        push rbx
        mov rbx, [rsi + ELF64_HEADER_PHOFF]
    @@: test edx, edx
        jz .no_pt_load_found
        cmp dword [rsi + rbx + ELF64_PHDR_TYPE], ELF64_PHTYPE_LOAD
        je .found_pt_load
        add rbx, rcx
        dec edx
        jmp @b

        .no_pt_load_found:
            pop rbx
            pop rdx
            jmp .error

        .found_pt_load:
            ; found first pt_load
            mov rax, [rsi + rbx + ELF64_PHDR_VADDR]
            pop rbx ; target load base address requested by caller
            pop rdx ; phnum count

            ; delta = (target_base - preferred_base)
            test rbx, rbx
            jnz @f
            mov rbx, rax
        @@: sub rbx, rax
            mov rdi, rbx ; store delta in rdi across header loop

        ; load pt_load phdrs
        mov rcx, [rsi + ELF64_HEADER_PHOFF]

        .next_header:
            test edx, edx
            jz .loaded

            cmp dword [rsi + rcx + ELF64_PHDR_TYPE], ELF64_PHTYPE_LOAD
            jne .skip

            push rcx
            push rdx

            lea rcx, [rsi + rcx]
            mov rbx, rsi
            mov rdx, rdi ; load delta
            call elf64_load_segment

            pop rdx
            pop rcx
            jc .error_with_delta

        .skip:
            movzx eax, word [rsi + ELF64_HEADER_PHENTSIZE]
            add rcx, rax
            dec edx
            jmp .next_header

        .loaded:
            mov rdx, rdi ; rdx = delta
            mov rax, [rsi + ELF64_HEADER_ENTRY]
            add rax, rdx ; rax = rebased entry point
            clc
            jmp .exit

        .error_with_delta:
        .error:
            stc

        .exit:
            pop rdi
            pop rsi
            pop rdx
            pop rcx
            pop rbx
            ret
    else
        push ebx
        push ecx
        push edx
        push esi
        push edi

        mov esi, eax

        ; check phdr size
        movzx ecx, word [esi + ELF64_HEADER_PHENTSIZE]
        cmp ecx, ELF64_PHDR_SIZE
        jb .error

        ; check phdr count
        movzx edx, word [esi + ELF64_HEADER_PHNUM]
        test edx, edx
        jz .error

        ; find first pt_load_phdr to get preferred load base address
        push edx
        push ebx
        mov ebx, dword [esi + ELF64_HEADER_PHOFF]
    @@: test edx, edx
        jz .no_pt_load_found
        cmp dword [esi + ebx + ELF64_PHDR_TYPE], ELF64_PHTYPE_LOAD
        je .found_pt_load
        add ebx, ecx
        dec edx
        jmp @b

        .no_pt_load_found:
            pop ebx
            pop edx
            jmp .error

        .found_pt_load:
            ; found first pt_load
            mov eax, dword [esi + ebx + ELF64_PHDR_VADDR]
            pop ebx ; target load base address requested by caller
            pop edx ; phnum count

            ; delta = (target_base - preferred_base)
            test ebx, ebx
            jnz @f
            mov ebx, eax
        @@: sub ebx, eax
            mov edi, ebx ; store delta in edi across header loop

        ; load pt_load phdrs
        mov ecx, dword [esi + ELF64_HEADER_PHOFF]

        .next_header:
            test edx, edx
            jz .loaded

            cmp dword [esi + ecx + ELF64_PHDR_TYPE], ELF64_PHTYPE_LOAD
            jne .skip

            push ecx
            push edx

            lea ecx, [esi + ecx]
            mov ebx, esi
            mov edx, edi ; load delta
            call elf64_load_segment

            pop edx
            pop ecx
            jc .error_with_delta

        .skip:
            movzx eax, word [esi + ELF64_HEADER_PHENTSIZE]
            add ecx, eax
            dec edx
            jmp .next_header

        .loaded:
            mov edx, edi ; edx = delta
            mov eax, dword [esi + ELF64_HEADER_ENTRY]
            add eax, edx ; eax = rebased entry point
            clc
            jmp .exit

        .error_with_delta:
        .error:
            stc

        .exit:
            pop edi
            pop esi
            pop edx
            pop ecx
            pop ebx
            ret
    end if

elf64_load_file:

; in:
;   - eax/rax: pointer to image in memory
;   - ebx/rbx: target load address (0 = use default)
; out:
;   - eax/rax: entry point
;   - cf: set on error

    call elf64_is_file_supported?
    jc .error

    call elf64_load_phdrs
    ret

    .error:
        stc
        ret