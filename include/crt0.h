typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

struct frame {
    uint64_t rax;
    uint64_t rbx;
    uint64_t rcx;
    uint64_t rdx;
    uint64_t rsi;
    uint64_t rdi;
};

enum {
    SYSCALL_EXIT = 0,
    SYSCALL_RUN = 1,
    SYSCALL_MALLOC = 2,
    SYSCALL_FREE = 3,
    SYSCALL_POLL = 4,
    SYSCALL_READ_FILE = 5,
    SYSCALL_PORT = 6,
};

static inline uint8_t inb(uint16_t port)
{
    uint8_t val;
    __asm__ volatile (
        "inb %1, %0"
        : "=a"(val)
        : "Nd"(port)
    );
    return val;
}

static inline void outb(uint16_t port, uint8_t val)
{
    __asm__ volatile (
        "outb %0, %1"
        :: "a"(val), "Nd"(port)
    );
}

static struct frame syscall(uint64_t rax, uint64_t rbx, uint64_t rcx, uint64_t rdx, uint64_t rsi, uint64_t rdi)
{
    struct frame out;

    register uint64_t in_rax __asm__("rax") = rax;
    register uint64_t in_rbx __asm__("rbx") = rbx;
    register uint64_t in_rcx __asm__("rcx") = rcx;
    register uint64_t in_rdx __asm__("rdx") = rdx;
    register uint64_t in_rsi __asm__("rsi") = rsi;
    register uint64_t in_rdi __asm__("rdi") = rdi;

    __asm__ volatile (
        "int $0x80\n\t"
        : "+a"(in_rax), "+b"(in_rbx), "+c"(in_rcx), "+d"(in_rdx), "+S"(in_rsi), "+D"(in_rdi)
        :: "memory"
    );

    out.rax = in_rax;
    out.rbx = in_rbx;
    out.rcx = in_rcx;
    out.rdx = in_rdx;
    out.rsi = in_rsi;
    out.rdi = in_rdi;
    return out;
}

int main(void);
__attribute__((noreturn)) void _start(void)
{
    (void)main();
    __asm__ volatile (
        "mov $0, %%rax\n\t"
        "int $0x80\n\t"
        "1:\n\t"
        "hlt\n\t"
        "jmp 1b\n\t"
        ::: "rax", "memory"
    );
}
