format elf64 executable 3 at 0x1000
include "include/crt0.inc"
segment readable executable writable

main:
    ; ask permission to read from the keyboard data port
    mov rax, 6
    mov rbx, 0x60
    mov rcx, 1
    int 0x80

    ; print initial prompt once
    lea rsi, [prompt]
    call puts

    .loop:
        ; poll for keyboard input
        mov rax, 4 ; poll syscall
        int 0x80
        test al, 1 ; PROCESS_FLAG_KEY
        jz .loop

        ; convert to ascii
        in al, 0x60
        call scan2ascii

        ; submit command on Enter
        cmp al, 13
        je .submit

        test al, al
        jz .loop

        ; add char to buffer
        mov rbx, [cmd_buf.ptr]
        cmp rbx, 255
        jae .loop
        mov [cmd_buf + rbx], al
        inc rbx
        mov [cmd_buf.ptr], rbx
        
        jmp .loop

    .submit: 
        ; terminate string
        mov rbx, [cmd_buf.ptr]
        mov byte [cmd_buf + rbx], 0

        ; exec cmd
        mov rsi, cmd_buf
        mov rdi, cmd_buf.scratch
        call file2fat83
        mov rsi, cmd_buf.scratch
        mov rax, 1 ; exec syscall
        int 0x80 

        ; print cmd
        mov rbx, [cmd_buf.ptr]
        mov rsi, cmd_buf
        call puts
        mov qword [cmd_buf.ptr], 0

        ; newline
        mov al, 0xD
        out 0xE9, al
        mov al, 0xA
        out 0xE9, al

        ; print prompt
        lea rsi, [prompt]
        call puts

        jmp .loop

@@: ret

puts:

; in:
;   - rsi: ptr to string

    mov rbx, rsi
@@: mov al, [rbx]
    test al, al
    jz @f
    out 0xE9, al
    inc rbx
    jmp @b
@@: ret

scan2ascii:

; in:
;   - al: scancode
; out:
;   - al: ascii char

    push rbx

    call @f
    @@: pop rbx
    sub rbx, @b

    ; check if scancode is 0xE0 (extended key prefix)
    cmp al, 0xE0
    jne @f
    mov byte [.extended + rbx], 1
    jmp .no_char

    ; check if extended flag is set
@@: cmp byte [.extended + rbx], 1
    jne @f
    mov byte [.extended + rbx], 0 ; reset extended flag
    jmp .no_char

    ; check if break (bit 7)
@@: test al, 0x80
    jnz .handle_break

    cmp al, 0x2A ; left shift
    je .shift_down
    cmp al, 0x36 ; right shift
    je .shift_down

    cmp al, 0x3A ; bounds check
    jae .no_char

    ; lookup char in map
    movzx eax, al
    cmp byte [.shift + rbx], 1
    je @f

    ; normal lookup
    mov al, [scancodes + rbx + rax]
    jmp .exit

    ; shifted lookup
@@: mov al, [scancodes.shift + rbx + rax]
    jmp .exit

    .shift_down:
        mov byte [.shift + rbx], 1
        jmp .no_char

    .shift_up:
        mov byte [.shift + rbx], 0
        jmp .no_char

    .handle_break:
        and al, 0x7F ; strip break bit
        cmp al, 0x2A ; left shift release
        je .shift_up
        cmp al, 0x36 ; right shift release
        je .shift_up
        jmp .no_char

    .no_char:
        xor al, al

    .exit:
        pop rbx
        ret

    .shift: db 0
    .extended: db 0

file2fat83:

; in:
;   rsi = src
;   rdi = out

    mov r9, rdi ; keep start of output buffer

    ; prefill 8.3 buffer with spaces
    mov rcx, 11
    mov al, ' '
@@: mov [rdi], al
    inc rdi
    loop @b

    mov rdi, r9 ; current write pointer
    mov ecx, 8 ; chars left in basename
    xor r8d, r8d ; 0=base, 1=ext

    .next:
        mov al, [rsi]
        test al, al
        jz .exit

        cmp al, '.'
        je .ext

        ; lowercase to uppercase
        cmp al, 'a'
        jb @f
        cmp al, 'z'
        ja @f
        sub al, 32
    @@: test ecx, ecx
        jz .step

        ; write char if room remains in current part
        mov [rdi], al
        inc rdi
        dec ecx
        jmp .step

    .ext:
        cmp r8b, 1
        je .step
        mov r8b, 1
        lea rdi, [r9 + 8]
        mov ecx, 3

    .step:
        inc rsi
        jmp .next

    .exit:
        ret

segment readable writable
cmd_buf:
    times 256 db 0
    .scratch: times 256 db 0
    .ptr: dq 0

segment readable
prompt: db "> ", 0
scancodes:
    db  0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8, 9
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 39,  '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '

    .shift:
        db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8, 9
        db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13, 0, 'A', 'S'
        db 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|', 'Z', 'X', 'C', 'V'
        db 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' '