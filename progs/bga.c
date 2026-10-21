#include "crt0.h"

enum
{
    BGA_IOPORT_INDEX = 0x01CE,
    BGA_IOPORT_DATA = 0x01CF,
    BGA_INDEX_ID = 0,
    BGA_INDEX_XRES = 1,
    BGA_INDEX_YRES = 2,
    BGA_INDEX_BPP = 3,
    BGA_INDEX_ENABLE = 4,
    BGA_ID2 = 0xB0C2,
    BGA_DISABLED = 0x00,
    BGA_ENABLED = 0x01,
    BGA_LFB_ENABLED = 0x40,
};

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    u16 id;

    // ask for permission to use bga ports
    (void)syscall(SYSCALL_PORT, BGA_IOPORT_INDEX, 1, 0, 0, 0);
    (void)syscall(SYSCALL_PORT, BGA_IOPORT_DATA, 1, 0, 0, 0);
    (void)syscall(SYSCALL_PORT, 0x01D0, 1, 0, 0, 0);

    // check if bga is supported
    outw(BGA_IOPORT_INDEX, BGA_INDEX_ID);

    // check bga version
    id = inw(BGA_IOPORT_DATA);
    if(id < BGA_ID2) {
        return 0;
    }

    // disable vbe extensions and lfb
    outw(BGA_IOPORT_INDEX, BGA_INDEX_ENABLE);
    outw(BGA_IOPORT_DATA, BGA_DISABLED);

    // set width
    outw(BGA_IOPORT_INDEX, BGA_INDEX_XRES);
    outw(BGA_IOPORT_DATA, (u16)rbx);

    // set height
    outw(BGA_IOPORT_INDEX, BGA_INDEX_YRES);
    outw(BGA_IOPORT_DATA, (u16)rdx);

    // set bpp
    outw(BGA_IOPORT_INDEX, BGA_INDEX_BPP);
    outw(BGA_IOPORT_DATA, (u16)rcx);

    // enable vbe extensions and lfb again
    outw(BGA_IOPORT_INDEX, BGA_INDEX_ENABLE);
    outw(BGA_IOPORT_DATA, (u16)(BGA_ENABLED | BGA_LFB_ENABLED));

    return 0;
}