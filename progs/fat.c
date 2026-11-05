#include "crt0.h"

struct __attribute__((packed)) bpb
{
    u8 entry[3];
    u8 oem_id[8];
    u16 bytes_per_sector;
    u8 sectors_per_cluster;
    u16 reserved_sectors;
    u8 num_fats;
    u16 root_entries;
    u16 total_sectors_16;
    u8 media_descriptor;
    u16 sectors_per_fat;
    u16 sectors_per_track;
    u16 num_heads;
    u32 hidden_sectors;
    u32 total_sectors_32;
    u8 drive_number;
    u8 reserved;
    u8 boot_signature;
    u32 volume_id;
    u8 volume_label[11];
    u8 filesystem_type[8];
};

struct __attribute__((packed)) dirent
{
    u8 name[11];
    u8 attr;
    u8 reserved[14];
    u16 cluster;
    u32 size;
};

static void to83(const u8* name, u8* out)
{
    u32 i = 0;
    u32 base = 1;
    u8 c;

    for(; i < 11; ++i) {
        out[i] = ' ';
    }

    i = 0;
    for(; *name; ++name) {
        c = *name;
        if(c == '.') {
            if(!base) {
                continue;
            }
            base = 0;
            i = 8;
            continue;
        }
        if(c >= 'a' && c <= 'z') {
            c -= 32;
        }
        if(i < (base ? 8 : 11)) {
            out[i++] = c;
        }
    }
}

static long read_file(const u8* name, u8* buf)
{
    u8 sector[512];
    u8 name83[11];
    struct bpb bpb = *(const struct bpb*)0x7C00;
    struct dirent* ent = (struct dirent*)sector;

    u32 root_lba;
    u32 root_sectors;
    u32 data_lba;
    u32 cluster;
    u32 size;
    u32 s, e, i;

    root_lba = bpb.reserved_sectors + bpb.num_fats * bpb.sectors_per_fat;
    root_sectors = (bpb.root_entries + 15) / 16;
    data_lba = root_lba + root_sectors;

    to83(name, name83);

    for(s = 0; s < root_sectors; ++s) {
        (void)syscall(SYSCALL_READ_SECTOR, root_lba + s, 1, 0, 0, (u64)sector);

        for(e = 0; e < bpb.bytes_per_sector / sizeof(*ent); ++e) {
            // end of directory
            if(ent[e].name[0] == 0) {
                return -1;
            }

            // deleted entry
            if(ent[e].name[0] == 0xE5) {
                continue;
            }

            for(i = 0; i < 11 && ent[e].name[i] == name83[i]; ++i)
                ;

            if(i < 11) {
                continue;
            }

            cluster = ent[e].cluster;
            size = ent[e].size;

            // follow cluster chain until eoc (0xFFF8)
            while(cluster >= 2 && cluster < 0xFFF8) {
                (void)syscall(SYSCALL_READ_SECTOR,
                              data_lba + (cluster - 2) * bpb.sectors_per_cluster,
                              bpb.sectors_per_cluster, 0, 0, (u64)buf);
                buf += bpb.sectors_per_cluster * bpb.bytes_per_sector;

                // fat16 entries are 2 bytes, so 256 per sector
                (void)syscall(SYSCALL_READ_SECTOR, bpb.reserved_sectors + cluster / 256, 1, 0, 0,
                              (u64)sector);
                cluster = ((const u16*)sector)[cluster % 256];
            }

            return size;
        }
    }

    return -1;
}

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    struct frame frame;
    volatile struct resp* resp;
    u64 buf;
    long size;

    (void)rax;
    (void)rbx;
    (void)rcx;
    (void)rdx;
    (void)rsi;
    (void)rdi;

    for(;;) {
        frame = syscall(SYSCALL_POLL, 0, 0, 0, 0, 0);

        if(frame.rax & FLAG_READ_FILE) {
            resp = (volatile struct resp*)frame.rsi;
            buf = syscall(SYSCALL_MALLOC, 0, 0x10000, 0, 0, 0).rax;
            size = buf ? read_file((const u8*)frame.rbx, (u8*)buf) : -1;
            if(size < 0) {
                resp->stat = 2;
            } else {
                resp->ret = (u64)size;
                resp->arg = buf;
                resp->stat = 1;
            }
        }
    }

    return 0;
}
