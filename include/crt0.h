typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

struct frame {
    u64 rax;
    u64 rbx;
    u64 rcx;
    u64 rdx;
    u64 rsi;
    u64 rdi;
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

static inline u8 inb(u16 port)
{
    u8 val;
    __asm__ volatile (
        "inb %1, %0"
        : "=a"(val)
        : "Nd"(port)
    );
    return val;
}

static inline void outb(u16 port, u8 val)
{
    __asm__ volatile (
        "outb %0, %1"
        :: "a"(val), "Nd"(port)
    );
}

static inline u16 inw(u16 port)
{
    u16 val;
    __asm__ volatile (
        "inw %1, %0"
        : "=a"(val)
        : "Nd"(port)
    );
    return val;
}

static inline void outw(u16 port, u16 val)
{
    __asm__ volatile (
        "outw %0, %1"
        :: "a"(val), "Nd"(port)
    );
}

static struct frame syscall(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi)
{
    struct frame out;

    register u64 in_rax __asm__("rax") = rax;
    register u64 in_rbx __asm__("rbx") = rbx;
    register u64 in_rcx __asm__("rcx") = rcx;
    register u64 in_rdx __asm__("rdx") = rdx;
    register u64 in_rsi __asm__("rsi") = rsi;
    register u64 in_rdi __asm__("rdi") = rdi;

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

int main(u64 rax, u64 rbx, u64 rcx, u64 rdx, u64 rsi, u64 rdi);
__attribute__((noreturn)) void _start(void)
{
    u64 rax,rbx,rcx,rdx,rsi,rdi;

    __asm__ volatile (
        ""
        : "=a"(rax), "=b"(rbx), "=c"(rcx), "=d"(rdx), "=S"(rsi), "=D"(rdi)
    );

    (void)main(rax, rbx, rcx, rdx, rsi, rdi);
    __asm__ volatile (
        "mov $0, %%rax\n\t"
        "int $0x80\n\t"
        "1:\n\t"
        "hlt\n\t"
        "jmp 1b\n\t"
        ::: "rax", "memory"
    );
}
