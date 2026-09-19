#!/usr/bin/env python3

import struct
import sys
from pathlib import Path

# 1.44mb floppy:
#   1 reserved sector
#   9 sectors fat #1
#   9 sectors fat #2
#   14 sectors root directory
#   2847 data sectors

IMAGE_SIZE = 1474560
SECTOR_SIZE = 512
TOTAL_SECTORS = IMAGE_SIZE // SECTOR_SIZE
RESERVED_SECTORS = 1
NUM_FATS = 2
ROOT_ENTRIES = 224
SECTORS_PER_CLUSTER = 1
FAT_SIZE = 9
ROOT_DIR_SECTORS = (
    ROOT_ENTRIES * 32 + SECTOR_SIZE - 1
) // SECTOR_SIZE
DATA_START_SECTOR = (
    RESERVED_SECTORS
    + NUM_FATS * FAT_SIZE
    + ROOT_DIR_SECTORS
)

def write_sector(image, lba, data):
    if len(data) > SECTOR_SIZE:
        raise ValueError("data is larger than one sector")

    offset = lba * SECTOR_SIZE
    image[offset:offset + len(data)] = data

# make a fat16 8.3 filename from a normal filename
def fatify_name(name):
    name = name.upper()

    if "." in name:
        base, ext = name.split(".", 1)
    else:
        base = name
        ext = ""

    base = base[:8].ljust(8)
    ext = ext[:3].ljust(3)

    return (base + ext).encode("ascii")

def write_fat_entry(image, fat_start, cluster, value):
    offset = fat_start * SECTOR_SIZE + cluster * 2
    struct.pack_into("<H", image, offset, value)


def allocate_clusters(image, fat_start, data, start_cluster):
    cluster_size = SECTOR_SIZE * SECTORS_PER_CLUSTER
    cluster_count = (
        len(data) + cluster_size - 1
    ) // cluster_size

    if cluster_count == 0:
        cluster_count = 1

    first_cluster = start_cluster

    for i in range(cluster_count):
        cluster = start_cluster + i

        data_start = i * cluster_size
        data_end = min(data_start + cluster_size, len(data))

        chunk = data[data_start:data_end]

        # first data cluster
        lba = DATA_START_SECTOR + (
            cluster - 2
        ) * SECTORS_PER_CLUSTER

        write_sector(image, lba, chunk)

        # chain to the next cluster
        if i == cluster_count - 1:
            next_cluster = 0xFFFF
        else:
            next_cluster = cluster + 1

        write_fat_entry(
            image,
            fat_start,
            cluster,
            next_cluster,
        )

    return first_cluster, cluster_count

# create a root directory entry for a file
def add_root_entry(image, index, filename, first_cluster, file_size):
    root_start = (
        RESERVED_SECTORS
        + NUM_FATS * FAT_SIZE
    )

    offset = (
        root_start * SECTOR_SIZE
        + index * 32
    )

    entry = bytearray(32)
    entry[0:11] = fatify_name(filename)
    entry[11] = 0x20 # attr: archive

    # first cluster
    struct.pack_into(
        "<H",
        entry,
        26,
        first_cluster,
    )

    # file size
    struct.pack_into(
        "<I",
        entry,
        28,
        file_size,
    )

    image[offset:offset + 32] = entry


def main():
    if len(sys.argv) < 4:
        print(
            f"usage: {sys.argv[0]} "
            "bootsector.bin file1.bin [file2.bin ...] output.img"
        )
        sys.exit(1)

    bootsector_path = Path(sys.argv[1])
    output_path = Path(sys.argv[-1])

    # grab everything between the first and last arguments
    payload_paths = [Path(p) for p in sys.argv[2:-1]]

    bootsector = bootsector_path.read_bytes()

    if len(bootsector) != 512:
        raise ValueError(
            f"bootsector must be exactly 512 bytes "
            f"(got {len(bootsector)})"
        )

    image = bytearray(IMAGE_SIZE)
    bpb = bytearray(bootsector)

    # bytes per sector
    struct.pack_into("<H", bpb, 11, SECTOR_SIZE)

    # sectors per cluster
    bpb[13] = SECTORS_PER_CLUSTER

    # number of reserved sectors
    struct.pack_into(
        "<H",
        bpb,
        14,
        RESERVED_SECTORS,
    )

    # number of FATs
    bpb[16] = NUM_FATS

    # root directory entries
    struct.pack_into(
        "<H",
        bpb,
        17,
        ROOT_ENTRIES,
    )

    # total sectors (16-bit field)
    struct.pack_into(
        "<H",
        bpb,
        19,
        TOTAL_SECTORS,
    )

    # media descriptor: 0xf0 = floppy
    bpb[21] = 0xf0

    # sectors per fat
    struct.pack_into(
        "<H",
        bpb,
        22,
        FAT_SIZE,
    )

    # sectors per track
    struct.pack_into(
        "<H",
        bpb,
        24,
        18,
    )

    # number of heads
    struct.pack_into(
        "<H",
        bpb,
        26,
        2,
    )

    # number of hidden sectors
    struct.pack_into(
        "<I",
        bpb,
        28,
        0,
    )

    # drive number
    bpb[36] = 0x80

    # bpb signature
    bpb[38] = 0x29

    # volume ID
    struct.pack_into(
        "<I",
        bpb,
        39,
        0x12345678,
    )

    # volume label
    bpb[43:54] = b"asmos".ljust(11)

    # filesystem type
    bpb[54:62] = b"FAT16".ljust(8)

    # bpb signature
    bpb[510] = 0x55
    bpb[511] = 0xaa

    write_sector(image, 0, bpb)

    fat1_start = RESERVED_SECTORS
    fat2_start = (
        RESERVED_SECTORS + FAT_SIZE
    )

    # fat[0]
    write_fat_entry(
        image,
        fat1_start,
        0,
        0xFFF8,
    )

    # fat[1]
    write_fat_entry(
        image,
        fat1_start,
        1,
        0xFFFF,
    )

    # copy initial fat entries to fat #2
    write_fat_entry(
        image,
        fat2_start,
        0,
        0xFFF8,
    )

    write_fat_entry(
        image,
        fat2_start,
        1,
        0xFFFF,
    )

    current_cluster = 2
    files = []

    # add all payload files to the image
    for idx, path in enumerate(payload_paths):
        data = path.read_bytes()
        filename = path.name

        start_cluster, num_clusters = allocate_clusters(
            image,
            fat1_start,
            data,
            current_cluster,
        )

        add_root_entry(
            image,
            idx,
            filename,
            start_cluster,
            len(data),
        )

        lba = (
            DATA_START_SECTOR
            + (start_cluster - 2)
            * SECTORS_PER_CLUSTER
        )
        sectors = (len(data) + SECTOR_SIZE - 1) // SECTOR_SIZE

        files.append({
            "name": filename,
            "cluster": start_cluster,
            "clusters": num_clusters,
            "lba": lba,
            "bytes": len(data),
            "sectors": sectors
        })

        current_cluster += num_clusters

    # copy fat #1 to fat #2
    fat1_offset = fat1_start * SECTOR_SIZE
    fat2_offset = fat2_start * SECTOR_SIZE

    image[
        fat2_offset:fat2_offset + FAT_SIZE * SECTOR_SIZE
    ] = image[
        fat1_offset:fat1_offset + FAT_SIZE * SECTOR_SIZE
    ]

    # patch the bootsector with information from the first file
    if files:
        first_file = files[0]
        struct.pack_into("<H", image, 0x40, first_file["sectors"])
        struct.pack_into("<Q", image, 0x46, first_file["lba"])

    output_path.write_bytes(image)

    print("Created:", output_path)
    print()
    print("FAT16 layout:")
    print(f"\tFAT #1: LBA {fat1_start}")
    print(f"\tFAT #2: LBA {fat2_start}")
    print(
        f"\tRoot dir: LBA "
        f"{fat1_start + NUM_FATS * FAT_SIZE}"
    )
    print(f"\tData: LBA {DATA_START_SECTOR}")
    print()
    print("Files:")
    
    for info in files:
        print(
            f"\t{info['name']}: "
            f"cluster {info['cluster']}, "
            f"LBA {info['lba']}, "
            f"{info['bytes']} bytes, "
            f"{info['clusters']} clusters"
        )


if __name__ == "__main__":
    main()