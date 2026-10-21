#include "crt0.h"

static void puts(const char* text)
{
    while(*text) {
        outb(0xE9, (u8)*text++);
    }
}

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    struct frame frame;

    (void)syscall(SYSCALL_PORT, 0xE9, 1, 0, 0, 0);

    frame = syscall(SYSCALL_READ_FILE, 0, 0, 0, (u64) "README.txt", 0);
    if(frame.rax == 0) {
        return -1;
    }

    puts((const char*)frame.rax);

    return 0;
}