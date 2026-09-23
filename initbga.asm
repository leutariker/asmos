BGA_IOPORT_INDEX = 0x01CE
BGA_IOPORT_DATA = 0x01CF

BGA_INDEX_ID = 0
BGA_INDEX_XRES = 1
BGA_INDEX_YRES = 2
BGA_INDEX_BPP = 3
BGA_INDEX_ENABLE = 4
BGA_INDEX_BANK = 5
BGA_INDEX_VIRT_WIDTH = 6
BGA_INDEX_VIRT_HEIGHT = 7
BGA_INDEX_X_OFFSET = 8
BGA_INDEX_Y_OFFSET = 9

BGA_ID0 = 0xB0C0
BGA_ID1 = 0xB0C1
BGA_ID2 = 0xB0C2
BGA_ID3 = 0xB0C3
BGA_ID4 = 0xB0C4
BGA_ID5 = 0xB0C5

BGA_DISABLED = 0x00
BGA_ENABLED = 0x01
BGA_GETCAPS = 0x02
BGA_8BIT_DAC = 0x20
BGA_LFB_ENABLED = 0x40
BGA_NOCLEARMEM = 0x80

BGA_BANK_SIZE_KB = 64
BGA_BANK_ADDRESS = 0xA0000

format ELF executable 3 at 0x1000
use64
entry start
segment readable executable writable

start:

; in:
;   - rax: width
;   - rbx: height
;   - cx:  bpp

    push rcx
    push rbx
    push rax

    ; check if bga is supported
    mov dx, BGA_IOPORT_INDEX
    mov ax, BGA_INDEX_ID
    out dx, ax

    ; check bga version
    mov dx, BGA_IOPORT_DATA
    in ax, dx
    cmp ax, BGA_ID4
    jb @f

    ; disable vbe extensions and lfb
    mov dx, BGA_IOPORT_INDEX
    mov ax, BGA_INDEX_ENABLE
    out dx, ax

    mov dx, BGA_IOPORT_DATA
    mov ax, BGA_DISABLED
    out dx, ax

    ; set width
    mov dx, BGA_IOPORT_INDEX
    mov ax, BGA_INDEX_XRES
    out dx, ax

    mov dx, BGA_IOPORT_DATA
    pop rax ; pop width
    out dx, ax

    ; set height
    mov dx, BGA_IOPORT_INDEX
    mov ax, BGA_INDEX_YRES
    out dx, ax

    mov dx, BGA_IOPORT_DATA
    pop rax ; pop height
    out dx, ax

    ; set bpp
    mov dx, BGA_IOPORT_INDEX
    mov ax, BGA_INDEX_BPP
    out dx, ax

    mov dx, BGA_IOPORT_DATA
    pop rax ; pop bpp
    out dx, ax

    ; enable vbe extensions and lfb again
    mov dx, BGA_IOPORT_INDEX
    mov ax, BGA_INDEX_ENABLE
    out dx, ax

    mov dx, BGA_IOPORT_DATA
    mov ax, BGA_ENABLED or BGA_LFB_ENABLED
    out dx, ax

    ret

@@: add rsp, 24
    ret