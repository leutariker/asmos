#include "crt0.h"

struct __attribute__((packed)) ehdr
{
    u8 ident[16];
    u16 type;
    u16 machine;
    u32 version;
    u64 entry;
    u64 phoff;
    u64 shoff;
    u32 flags;
    u16 ehsize;
    u16 phentsize;
    u16 phnum;
    u16 shentsize;
    u16 shnum;
    u16 shstrndx;
};

struct __attribute__((packed)) phdr
{
    u32 type;
    u32 flags;
    u64 offset;
    u64 vaddr;
    u64 paddr;
    u64 filesz;
    u64 memsz;
    u64 align;
};

enum
{
    PT_LOAD = 1,
    ET_EXEC = 2,
    EM_X86_64 = 62,
};

// relocates the image to dest, returns the relocated entry point or 0 on error
static u64 load_elf(const u8* image, u8* dest)
{
    const struct ehdr* eh = (const struct ehdr*)image;
    const struct phdr* ph;
    u64 delta;
    u64 i, j;
    u8* dst;
    const u8* src;

    if(eh->ident[0] != 0x7F || eh->ident[1] != 'E' || eh->ident[2] != 'L' || eh->ident[3] != 'F') {
        return 0;
    }
    if(eh->ident[4] != 2 || eh->ident[5] != 1) {
        return 0;
    }
    if(eh->type != ET_EXEC || eh->machine != EM_X86_64) {
        return 0;
    }
    if(eh->phentsize < sizeof(*ph)) {
        return 0;
    }

    // the first PT_LOAD defines the link address
    ph = (const struct phdr*)(image + eh->phoff);
    for(i = 0; i < eh->phnum; ++i) {
        if(((const struct phdr*)((const u8*)ph + i * eh->phentsize))->type == PT_LOAD) {
            break;
        }
    }
    if(i == eh->phnum) {
        return 0;
    }
    delta = (u64)dest - ((const struct phdr*)((const u8*)ph + i * eh->phentsize))->vaddr;

    for(i = 0; i < eh->phnum; ++i) {
        const struct phdr* p = (const struct phdr*)((const u8*)ph + i * eh->phentsize);
        if(p->type != PT_LOAD) {
            continue;
        }
        if(p->memsz < p->filesz) {
            return 0;
        }

        src = image + p->offset;
        dst = (u8*)(p->vaddr + delta);
        for(j = 0; j < p->filesz; ++j) {
            dst[j] = src[j];
        }
        for(; j < p->memsz; ++j) {
            dst[j] = 0;
        }
    }

    return eh->entry + delta;
}

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    volatile struct resp* resp;
    struct frame frame;
    u64 entry;

    (void)rax;
    (void)rbx;
    (void)rcx;
    (void)rdx;
    (void)rsi;
    (void)rdi;

    for(;;) {
        frame = syscall(SYSCALL_POLL, 0, 0, 0, 0, 0);

        if(frame.rax & FLAG_RELOC) {
            // rbx = elf image to reloc
            // rsi = status (state, entry)
            // rdi = preferred load address

            resp = (volatile struct resp*)frame.rsi;
            entry = load_elf((const u8*)frame.rbx, (u8*)frame.rdi);
            if(!entry) {
                resp->stat = 2;
            } else {
                resp->ret = entry;
                resp->stat = 1;
            }
        }
    }

    return 0;
}
