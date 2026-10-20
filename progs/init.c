#include "crt0.h"

int main(void)
{
    syscall(SYSCALL_PORT, 0xE9, 1, 0, 0);
    outb(0xE9, 'X');
    return 0;
}