#include "crt0.h"

enum
{
    SCANCODE_COUNT = 58,
    KEYBOARD_PORT = 0x60,
    DEBUG_PORT = 0xE9,
    CMD_BUFFER_SIZE = 256,
};

static const char scancodes[SCANCODE_COUNT] = {
    0,   27,  '1', '2', '3', '4', '5', '6', '7', '8', '9',  '0', '-', '=',  8,
    9,   'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',  '[', ']', 13,   0,
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0,   '\\', 'z',
    'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,   '*',  0,   ' '};

static const char scancodes_shifted[SCANCODE_COUNT] = {
    0,   27,  '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8,
    9,   'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13,  0,
    'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0,   '|', 'Z',
    'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0,   '*', 0,   ' '};

static char cmd[CMD_BUFFER_SIZE];
static u64 cmd_len;
static u8 shift;
static u8 extended;

static void puts(const char* text)
{
    while(*text) {
        outb(DEBUG_PORT, (u8)*text++);
    }
}

static u8 scan2ascii(u8 scancode)
{
    if(scancode == 0xE0) {
        extended = 1;
        return 0;
    }

    if(extended) {
        extended = 0;
        return 0;
    }

    if(scancode & 0x80) {
        scancode &= 0x7F;
        if(scancode == 0x2A || scancode == 0x36) {
            shift = 0;
        }
        return 0;
    }

    if(scancode == 0x2A || scancode == 0x36) {
        shift = 1;
        return 0;
    }

    if(scancode >= SCANCODE_COUNT) {
        return 0;
    }

    return (u8)(shift ? scancodes_shifted[scancode] : scancodes[scancode]);
}

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    struct frame frame;
    u8 c;

    (void)rax;
    (void)rbx;
    (void)rcx;
    (void)rdx;
    (void)rsi;
    (void)rdi;

    // ask for permissions to use keyboard and debug ports
    (void)syscall(SYSCALL_PORT, KEYBOARD_PORT, 1, 0, 0, 0);
    (void)syscall(SYSCALL_PORT, DEBUG_PORT, 1, 0, 0, 0);

    // prompt
    puts("> ");

    for(;;) {
        // poll for keyboard input
        frame = syscall(SYSCALL_POLL, 0, 0, 0, 0, 0);
        if((frame.rax & 1) == 0) {
            continue;
        }
        c = scan2ascii(inb(KEYBOARD_PORT));

        switch(c) {
        case 13:
            // run file
            cmd[cmd_len] = 0;
            (void)syscall(SYSCALL_RUN, 0, 0, 0, (u64)cmd, 0);

            // write out cmd and reset buffer
            puts(cmd);
            cmd_len = 0;
            puts("\r\n> ");

            continue;

        case 0:
            continue;

        default:
            if(cmd_len < CMD_BUFFER_SIZE - 1) {
                cmd[cmd_len++] = (char)c;
            }
            continue;
        }
    }
}