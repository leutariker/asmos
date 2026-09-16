; typedef struct {
; 	uint8_t		e_ident[ELF_NIDENT];
; 	Elf32_Half	e_type;
; 	Elf32_Half	e_machine;
; 	Elf32_Word	e_version;
; 	Elf32_Addr	e_entry;
; 	Elf32_Off	e_phoff;
; 	Elf32_Off	e_shoff;
; 	Elf32_Word	e_flags;
; 	Elf32_Half	e_ehsize;
; 	Elf32_Half	e_phentsize;
; 	Elf32_Half	e_phnum;
; 	Elf32_Half	e_shentsize;
; 	Elf32_Half	e_shnum;
; 	Elf32_Half	e_shstrndx;
; } Elf32_Ehdr;

; typedef struct {
; 	Elf32_Word	sh_name;
; 	Elf32_Word	sh_type;
; 	Elf32_Word	sh_flags;
; 	Elf32_Addr	sh_addr;
; 	Elf32_Off	sh_offset;
; 	Elf32_Word	sh_size;
; 	Elf32_Word	sh_link;
; 	Elf32_Word	sh_info;
; 	Elf32_Word	sh_addralign;
; 	Elf32_Word	sh_entsize;
; } Elf32_Shdr;

; typedef struct {
; 	Elf32_Word		st_name;
; 	Elf32_Addr		st_value;
; 	Elf32_Word		st_size;
; 	uint8_t			st_info;
; 	uint8_t			st_other;
; 	Elf32_Half		st_shndx;
; } Elf32_Sym;

; typedef struct {
; 	Elf32_Addr		r_offset;
; 	Elf32_Word		r_info;
; } Elf32_Rel;

; typedef struct {
; 	Elf32_Addr		r_offset;
; 	Elf32_Word		r_info;
; 	Elf32_Sword		r_addend;
; } Elf32_Rela;

; enum Elf_Ident {
; 	EI_MAG0		= 0, // 0x7F
; 	EI_MAG1		= 1, // 'E'
; 	EI_MAG2		= 2, // 'L'
; 	EI_MAG3		= 3, // 'F'
; 	EI_CLASS	= 4, // Architecture (32/64)
; 	EI_DATA		= 5, // Byte Order
; 	EI_VERSION	= 6, // ELF Version
; 	EI_OSABI	= 7, // OS Specific
; 	EI_ABIVERSION	= 8, // OS Specific
; 	EI_PAD		= 9  // Padding
; };

; enum ShT_Types {
; 	SHT_NULL	= 0,   // Null section
; 	SHT_PROGBITS	= 1,   // Program information
; 	SHT_SYMTAB	= 2,   // Symbol table
; 	SHT_STRTAB	= 3,   // String table
; 	SHT_RELA	= 4,   // Relocation (w/ addend)
; 	SHT_NOBITS	= 8,   // Not present in file
; 	SHT_REL		= 9,   // Relocation (no addend)
; };

; enum ShT_Attributes {
; 	SHF_WRITE	= 0x01, // Writable section
; 	SHF_ALLOC	= 0x02  // Exists in memory
; };

; enum RtT_Types {
; 	R_386_NONE		= 0, // No relocation
; 	R_386_32		= 1, // Symbol + Offset
; 	R_386_PC32		= 2  // Symbol + Offset - Section Offset
; };


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