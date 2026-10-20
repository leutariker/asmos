#include "crt0.h"

static uint64_t args[4];
static uint8_t toklen;
static char token[32];
static char filename[11];

static void file2fat83(const char* src, char out[11])
{
    uint64_t i;
    uint8_t base_len;
    uint8_t ext_len;
    uint8_t in_ext;
    char ch;

    for (i = 0; i < 11; ++i) {
        out[i] = ' ';
    }

    base_len = 0;
    ext_len = 0;
    in_ext = 0;

    while (*src) {
        ch = *src++;

        if (ch == '.') {
            if (in_ext == 0) {
                in_ext = 1;
            }
            continue;
        }

        if (ch >= 'a' && ch <= 'z') {
            ch = (char)(ch - ('a' - 'A'));
        }

        if (in_ext == 0) {
            if (base_len < 8) {
                out[base_len++] = ch;
            }
        } else {
            if (ext_len < 3) {
                out[8 + ext_len++] = ch;
            }
        }
    }
}

static void consume(void)
{
    int idx;
    uint64_t n;
    const char* p;
    char ch;

    if (toklen == 0) {
        return;
    }

    token[toklen] = 0;
    toklen = 0;

    // parse register names (rbx=, rcx=, rdx=, rdi=)
    idx = -1;
    if (token[0] == 'R' && token[3] == '=') {
        if (token[1] == 'B' && token[2] == 'X') idx = 0;
        if (token[1] == 'C' && token[2] == 'X') idx = 1;
        if (token[1] == 'D' && token[2] == 'X') idx = 2;
        if (token[1] == 'D' && token[2] == 'I') idx = 3;
    }

    // parse decimals (e.g. rbx=1234)
    if (idx >= 0) {
        n = 0;
        p = token + 4;
        while (1) {
            ch = *p;
            if (ch == 0) {
                args[idx] = n;
                return;
            }
            if (ch < '0' || ch > '9') {
                return;
            }
            n = (n * 10u) + (uint64_t)(ch - '0');
            ++p;
        }
    }

    file2fat83(token, filename);
    (void)syscall(SYSCALL_RUN, args[0], args[1], args[2], (uint64_t)filename, args[3]);
}

static void parse(const uint8_t* input, const uint8_t* end)
{
    uint8_t ch;

    while (input < end) {
        ch = *input++;

        // whitespace
        if (ch == ' ' || ch == 9 || ch == 13) {
            consume();
            continue;
        }

        // newline
        if (ch == 10) {
            consume();
            args[0] = 0;
            args[1] = 0;
            args[2] = 0;
            args[3] = 0;
            continue;
        }

        if (toklen < 31) {
            token[toklen] = (char)ch;
            ++toklen;
        }
    }

    consume();
}

int main(void)
{
    char init_txt[11] = "INIT    TXT";
    struct frame frame;
    const uint8_t* input;
    const uint8_t* end;

    frame = syscall(SYSCALL_READ_FILE, 0, 0, 0, (uint64_t)init_txt, 0);
    if (frame.rax == 0) {
        return 0;
    }

    input = (const uint8_t*)frame.rax;
    end = input + frame.rbx;
    args[0] = 0;
    args[1] = 0;
    args[2] = 0;
    args[3] = 0;
    toklen = 0;

    parse(input, end);
    return 0;
}