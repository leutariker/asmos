format elf64 executable 3 at 0x1000
include "include/crt0.inc"
segment readable executable writable

main:
    lea rsi, [init_txt]
    mov rax, 5 ; read file syscall
    int 0x80
    test rax, rax
    jz @f

    mov [input_ptr], rax ; syscall returns start of file in rax
    add rbx, rax
    mov [input_end], rbx ; syscall returns end of file in rbx
    call parse

@@: ret

parse:
    ; check eof
    mov rsi, [input_ptr]
    cmp rsi, [input_end]
    jae .eof

    ; consume one char
    mov al, [rsi]
    inc rsi
    mov [input_ptr], rsi

    ; check for spaces tabs and cr/cf
    cmp al, ' '
    je .separator
    cmp al, 9
    je .separator
    cmp al, 13
    je .separator
    cmp al, 10 ; line feed ends current cmd and clears arg
    je .newline

    ; append to stream
    movzx ecx, byte [toklen]
    cmp ecx, 31
    jae parse
    lea rdi, [token]
    mov [rdi + rcx], al
    inc byte [toklen]
    jmp parse

    .separator:
        call process_token
        jmp parse

    .newline:
        call process_token

        ; clear args for next cmd
        lea rdi, [args]
        mov qword [rdi], 0
        mov qword [rdi + 8], 0
        mov qword [rdi + 16], 0
        mov qword [rdi + 24], 0

        jmp parse

    .eof:
        ; process final token
        call process_token
        ret

process_token:
    ; ignore empty tokens
    movzx ecx, byte [toklen]
    test ecx, ecx
    jz .done
    lea rsi, [token]
    mov byte [rsi + rcx], 0
    mov byte [toklen], 0

    ; parse register args
    cmp byte [rsi], 'R'
    jne .run
    cmp byte [rsi + 3], '='
    jne .run
    lea rdi, [args]
    cmp word [rsi + 1], 'BX'
    je .number
    add rdi, 8
    cmp word [rsi + 1], 'CX'
    je .number
    add rdi, 8
    cmp word [rsi + 1], 'DX'
    je .number
    add rdi, 8
    cmp word [rsi + 1], 'DI'
    jne .run

    .number:
        ; parse decimal after '=' e.g. rbx=1234
        lea rsi, [token + 4]
        xor eax, eax

    .digit:
        ; accumulate digits in rax
        movzx edx, byte [rsi]
        test dl, dl
        jz .store
        cmp dl, '0'
        jb .done
        cmp dl, '9'
        ja .done
        imul rax, rax, 10
        sub edx, '0'
        add rax, rdx
        inc rsi
        jmp .digit

    .store:
        mov [rdi], rax ; store value of reg arg
        jmp .done

    .run:
        ; convert file name to fat 8.3
        lea rsi, [token]
        lea rdi, [filename]
        call file2fat83

        ; run program with syscall 1
        lea rsi, [filename]
        lea rdi, [args]
        mov rbx, [rdi]
        mov rcx, [rdi + 8]
        mov rdx, [rdi + 16]
        mov rdi, [rdi + 24]
        mov rax, 1
        int 0x80
        
    .done:
        ret

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
input_ptr: dq 0
input_end: dq 0
args: dq 0, 0, 0, 0
toklen: db 0
token: times 32 db 0
filename: times 11 db " "

segment readable
init_txt: db "INIT    TXT"