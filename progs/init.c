#include "crt0.h"

static u64 args[4];
static u8 toklen;
static char token[32];

static void consume(void)
{
    int idx;
    u64 n;
    const char* p;
    char c;

    if(toklen == 0) {
        return;
    }

    token[toklen] = 0;
    toklen = 0;

    // parse register names (rbx=, rcx=, rdx=, rdi=)
    idx = -1;
    if(token[0] == 'R' && token[3] == '=') {
        if(token[1] == 'B' && token[2] == 'X')
            idx = 0;
        if(token[1] == 'C' && token[2] == 'X')
            idx = 1;
        if(token[1] == 'D' && token[2] == 'X')
            idx = 2;
        if(token[1] == 'D' && token[2] == 'I')
            idx = 3;
    }

    // parse decimals (e.g. rbx=1234)
    if(idx >= 0) {
        n = 0;
        p = token + 4;
        while(1) {
            c = *p;
            if(c == 0) {
                args[idx] = n;
                return;
            }
            if(c < '0' || c > '9') {
                return;
            }
            n = (n * 10u) + (u64)(c - '0');
            ++p;
        }
    }

    (void)syscall(SYSCALL_RUN, args[0], args[1], args[2], (u64)token, args[3]);
}

static void parse(u8* input, u8* end)
{
    u8 c;

    while(input < end) {
        c = *input++;

        // whitespace
        if(c == ' ' || c == 9 || c == 13) {
            consume();
            continue;
        }

        // newline
        if(c == 10) {
            consume();
            args[0] = 0;
            args[1] = 0;
            args[2] = 0;
            args[3] = 0;
            continue;
        }

        if(toklen < 31) {
            token[toklen] = (char)c;
            ++toklen;
        }
    }

    consume();
}

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    (void)rax;
    (void)rbx;
    (void)rcx;
    (void)rdx;
    (void)rsi;
    (void)rdi;

    struct frame frame;
    u8* input;
    u8* end;

    frame = syscall(SYSCALL_READ_FILE, 0, 0, 0, (u64)"init.txt", 0);
    if(frame.rax == 0) {
        return 0;
    }

    input = (const u8*)frame.rax;
    end = input + frame.rbx;
    args[0] = 0;
    args[1] = 0;
    args[2] = 0;
    args[3] = 0;
    toklen = 0;

    parse(input, end);
    return 0;
}