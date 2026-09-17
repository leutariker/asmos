ELF32_TYPE_NONE = 0
ELF32_TYPE_REL = 1
ELF32_TYPE_EXEC = 2

ELF32_SHT_TYPE_NULL = 0
ELF32_SHT_TYPE_PROGBITS = 1
ELF32_SHT_TYPE_SYMTAB = 2
ELF32_SHT_TYPE_STRTAB = 3
ELF32_SHT_TYPE_RELA = 4
ELF32_SHT_TYPE_NOBITS = 8
ELF32_SHT_TYPE_REL = 9

ELF32_SHT_ATTR_WRITE = 0
ELF32_SHT_ATTR_ALLOC = 1

ELF32_RTTYPE_NONE = 0
ELF32_RTTYPE_32 = 1
ELF32_RTTYPE_PC32 = 2

ELF32_PHTYPE_NULL = 0
ELF32_PHTYPE_LOAD = 1

ELF32_HEADER_IDENT = 0
ELF32_HEADER_TYPE = ELF32_HEADER_IDENT + 16
ELF32_HEADER_MACHINE = ELF32_HEADER_TYPE + 2
ELF32_HEADER_VERSION = ELF32_HEADER_MACHINE + 2
ELF32_HEADER_ENTRY = ELF32_HEADER_VERSION + 4
ELF32_HEADER_PHOFF = ELF32_HEADER_ENTRY + 4
ELF32_HEADER_SHOFF = ELF32_HEADER_PHOFF + 4
ELF32_HEADER_FLAGS = ELF32_HEADER_SHOFF + 4
ELF32_HEADER_EHSIZE = ELF32_HEADER_FLAGS + 4
ELF32_HEADER_PHENTSIZE = ELF32_HEADER_EHSIZE + 2
ELF32_HEADER_PHNUM = ELF32_HEADER_PHENTSIZE + 2
ELF32_HEADER_SHENTSIZE = ELF32_HEADER_PHNUM + 2
ELF32_HEADER_SHNUM = ELF32_HEADER_SHENTSIZE + 2
ELF32_HEADER_SHSTRNDX = ELF32_HEADER_SHNUM + 2

ELF32_HEADER_IDENT_MAGIC = 0
ELF32_HEADER_IDENT_CLASS = 4
ELF32_HEADER_IDENT_DATA = 5
ELF32_HEADER_IDENT_VERSION = 6
ELF32_HEADER_IDENT_OSABI = 7
ELF32_HEADER_IDENT_ABIVERSION = 8
ELF32_HEADER_IDENT_PAD = 9

ELF32_SHDR_NAME = 0
ELF32_SHDR_TYPE = ELF32_SHDR_NAME + 4
ELF32_SHDR_FLAGS = ELF32_SHDR_TYPE + 4
ELF32_SHDR_ADDR = ELF32_SHDR_FLAGS + 4
ELF32_SHDR_OFFSET = ELF32_SHDR_ADDR + 4
ELF32_SHDR_SIZE = ELF32_SHDR_OFFSET + 4
ELF32_SHDR_LINK = ELF32_SHDR_SIZE + 4
ELF32_SHDR_INFO = ELF32_SHDR_LINK + 4
ELF32_SHDR_ADDRALIGN = ELF32_SHDR_INFO + 4
ELF32_SHDR_ENTSIZE = ELF32_SHDR_ADDRALIGN + 4

ELF32_SYM_NAME = 0
ELF32_SYM_VALUE = ELF32_SYM_NAME + 4
ELF32_SYM_SIZE = ELF32_SYM_VALUE + 4
ELF32_SYM_INFO = ELF32_SYM_SIZE + 4
ELF32_SYM_OTHER = ELF32_SYM_INFO + 1
ELF32_SYM_SHNDX = ELF32_SYM_OTHER + 1

ELF32_PHDR_TYPE = 0
ELF32_PHDR_OFFSET = ELF32_PHDR_TYPE + 4
ELF32_PHDR_VADDR = ELF32_PHDR_OFFSET + 4
ELF32_PHDR_PADDR = ELF32_PHDR_VADDR + 4
ELF32_PHDR_FILESZ = ELF32_PHDR_PADDR + 4
ELF32_PHDR_MEMSZ = ELF32_PHDR_FILESZ + 4
ELF32_PHDR_FLAGS = ELF32_PHDR_MEMSZ + 4
ELF32_PHDR_ALIGN = ELF32_PHDR_FLAGS + 4
ELF32_PHDR_SIZE = ELF32_PHDR_ALIGN + 4

elf32_is_file_supported?:

; in:
;   - eax: ptr to elf32_header
; out:
;   - cf: 1 if not supported, 0 if supported

    push ebx
    
    test eax, eax
    jz @f

    cmp dword [eax + ELF32_HEADER_IDENT_MAGIC], 0x464C457F ; 0x7F, "ELF" in little endian
    jne @f

    cmp byte [eax + ELF32_HEADER_IDENT_CLASS], 1 ; x86
    jne @f

    cmp byte [eax + ELF32_HEADER_IDENT_DATA], 1 ; little endian
    jne @f

    cmp word [eax + ELF32_HEADER_MACHINE], 3 ; x86
    jne @f

    cmp byte [eax + ELF32_HEADER_IDENT_VERSION], 1 ; current version
    jne @f

    cmp word [eax + ELF32_HEADER_TYPE], 1 ; relocatable
    jb @f

    cmp word [eax + ELF32_HEADER_TYPE], 2 ; executable
    ja @f

    clc
    pop ebx
    ret

    @@:
        stc
        pop ebx
        ret

elf32_load_segment:

; in:
;   - ebx: pointer to an ELF32 image in memory
;   - ecx: pointer to an ELF32 program header
; out:
;   - cf: set if the segment cannot be loaded

    push eax
    push ecx
    push edx
    push esi
    push edi

    ; check memsz >= filesz
    mov eax, [ecx + ELF32_PHDR_FILESZ]
    cmp eax, [ecx + ELF32_PHDR_MEMSZ]
    ja .error

    ; copy segment to memory
    mov esi, [ecx + ELF32_PHDR_OFFSET]
    add esi, ebx
    jc .error
    mov edi, [ecx + ELF32_PHDR_PADDR]
    push ecx
    push eax
    mov ecx, eax
    rep movsb

    ; clear out remaining memory
    pop eax
    pop ecx
    mov edx, [ecx + ELF32_PHDR_MEMSZ]
    sub edx, eax
    xor eax, eax
    mov ecx, edx
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

elf32_load_phdrs:

; in:
;   - eax: pointer to an elf image in memory
; out:
;   - eax: entry point
;   - cf: set if the program headers cannot be loaded

    push ebx
    push ecx
    push edx

    mov ebx, eax
    cmp word [ebx + ELF32_HEADER_PHENTSIZE], ELF32_PHDR_SIZE
    jb .error

    ; bounds-check the program header table against the image
    movzx edx, word [ebx + ELF32_HEADER_PHNUM]
    mov eax, [ebx + ELF32_HEADER_PHOFF]
    movzx ecx, word [ebx + ELF32_HEADER_PHENTSIZE]
    imul ecx, edx
    add eax, ecx
    jc .error

    mov eax, [ebx + ELF32_HEADER_ENTRY]
    push eax
    mov ecx, [ebx + ELF32_HEADER_PHOFF]

    .next_header:
        test edx, edx
        jz .loaded

        cmp dword [ebx + ecx + ELF32_PHDR_TYPE], ELF32_PHTYPE_LOAD
        jne .skip

        push ecx
        add ecx, ebx
        call elf32_load_segment
        pop ecx
        jc .error_with_entry

    .skip:
        movzx eax, word [ebx + ELF32_HEADER_PHENTSIZE]
        add ecx, eax
        dec edx
        jmp .next_header

    .loaded:
        pop eax
        clc
        jmp .exit

    .error_with_entry:
        add esp, 4 ; discard entry point
    .error:
        stc

    .exit:
        pop edx
        pop ecx
        pop ebx
        ret

elf32_load_file:

; in:
;   - eax: pointer to an ELF32 image in memory
; out:
;   - eax: entry point
;   - cf: set if the image cannot be loaded

    call elf32_is_file_supported?
    jc .error

    call elf32_load_phdrs
    ret

    .error:
        stc
        ret