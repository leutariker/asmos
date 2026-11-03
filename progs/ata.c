#include "crt0.h"

enum
{
    ATA_DATA = 0x1F0,
    ATA_COUNT = 0x1F2,
    ATA_LBA_LO = 0x1F3,
    ATA_LBA_MID = 0x1F4,
    ATA_LBA_HI = 0x1F5,
    ATA_DRIVE = 0x1F6,
    ATA_CMD = 0x1F7,
    ATA_STATUS = 0x1F7,
    ATA_CMD_READ = 0x20,
    ATA_SR_BSY = 0x80,
    ATA_SR_DRQ = 0x08,
    ATA_SR_ERR = 0x01,
    ATA_SR_DF = 0x20,
};

static int read_sector(u32 lba, u16* buf)
{
    u8 status;
    int i;

    outb(ATA_DRIVE, (u8)(0xE0 | ((lba >> 24) & 0x0F)));
    outb(ATA_COUNT, 1);
    outb(ATA_LBA_LO, (u8)lba);
    outb(ATA_LBA_MID, (u8)(lba >> 8));
    outb(ATA_LBA_HI, (u8)(lba >> 16));
    outb(ATA_CMD, ATA_CMD_READ);

    do {
        status = inb(ATA_STATUS);
    } while(status & ATA_SR_BSY);
    if(status & (ATA_SR_ERR | ATA_SR_DF) || !(status & ATA_SR_DRQ)) {
        return -1;
    }

    for(i = 0; i < 256; ++i) {
        buf[i] = inw(ATA_DATA);
    }

    return 0;
}

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    struct frame frame;
    u64 i;
    u16 port;

    (void)rax;
    (void)rbx;
    (void)rcx;
    (void)rdx;
    (void)rsi;
    (void)rdi;

    for(port = ATA_DATA; port <= ATA_STATUS; ++port) {
        (void)syscall(SYSCALL_PORT, port, 1, 0, 0, 0);
    }

    for(;;) {
        frame = syscall(SYSCALL_POLL, 0, 0, 0, 0, 0);
        if(!(frame.rax & FLAG_READ)) {
            continue;
        }

        // rbx = lba, rcx = count, rdi = buffer
        for(i = 0; i < frame.rcx; ++i) {
            if(read_sector((u32)(frame.rbx + i), (u16*)frame.rdi + (i * 256)) < 0) {
                break;
            }
        }

        // completion flag
        if(frame.rsi) {
            *(volatile u64*)frame.rsi = 1;
        }
    }

    return 0;
}
