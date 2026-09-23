format ELF executable 3 at 0x1000
use32
entry start
segment readable executable writable

start:
    in al, 0x60
    call scan2ascii

    test al, al
    jz @f

    out 0xE9, al

@@: ret

scan2ascii:

; in:
;   - al: scancode
; out:
;   - al: ascii char

    push ebx

    call .get_pc
.get_pc:
    pop ebx
    sub ebx, .get_pc

    ; check if scancode is 0xE0 (extended key prefix)
    cmp al, 0xE0
    jne @f
    mov byte [.extended + ebx], 1
    jmp .no_char

    ; check if extended flag is set
@@: cmp byte [.extended + ebx], 1
    jne @f
    mov byte [.extended + ebx], 0 ; reset extended flag
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
    cmp byte [.shift + ebx], 1
    je @f

    ; normal lookup
    mov al, [scancodes + ebx + eax]
    jmp .exit

    ; shifted lookup
@@: mov al, [scancodes.shift + ebx + eax]
    jmp .exit

    .shift_down:
        mov byte [.shift + ebx], 1
        jmp .no_char

    .shift_up:
        mov byte [.shift + ebx], 0
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
        pop ebx
        ret

    .shift: db 0
    .extended: db 0

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