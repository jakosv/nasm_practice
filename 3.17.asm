%include "kernel.inc"
%include "procedure.inc"

global _start

section .text

; is_letter(char address) -> AL (1 - true, 0 - false)
is_letter:
	push ebp
	mov ebp, esp

	mov al, [arg(1)]
	cmp al, 'A'				; if AL < 'A'
	jl .false				;	return false
	cmp al, 'Z'				; if AL <= 'Z'
	jle .true				;	'A' <= AL <= 'Z'

	cmp al, 'z'				; if Al > 'z'
	jg .false				;	return false
	cmp al, 'a'				; if AL >= 'a'
	jge .true				;	'a' <= AL <= 'z'
						; else
.false:	xor al, al				;	return false
	jmp short .quit
.true:	mov al, 1		
.quit:	mov esp, ebp
	pop ebp
	ret

section .bss
buf	resb 4096
char	resb 1

section .text
_start:
main:
	xor bl, bl				; set word flag := 0
	mov esi, 0				; ECX := 0 (buf size)
.read_char:
	kernel sys_read, stdin, char, 1		; read(char)
	test eax, eax				; check if read 0 bytes 
	jz .end_read				; file ended

	pcall is_letter, [char]			; AL := is_letter(char)
	test al, al				; if AL = 0
	jz .not_letter

	test bl, bl				; if word flag = 1
	jnz .add_char				; it's not first word char
	mov bl, 1				; else set word flag := 1	
	mov byte [buf + esi], '('		; insert open bracket
	inc esi					; increase buf size 
	jmp short .add_char

.not_letter:					; check if word ended
	test bl, bl				; if word flag = 0
	jz .add_char				; just add char to buf
	mov byte [buf + esi], ')'		; else add close bracket 
	inc esi					; increase buf size 
	xor bl, bl				; word flag := 0
	
.add_char:
	mov al, [char]
	mov [buf + esi], al			; add char to buf
	inc esi					; increase buf size
	cmp al, 10				; if AL = '\n'
	kernel sys_write, stdout, buf, esi	; write buf to stdout
	xor esi, esi				; ESI := 0 (clear buf)
	jmp .read_char				; read next char

.end_read:
	test bl, bl				; if word flag = 1
	jz .goon				; nothing to do 
	mov byte [buf + esi], ')'		; else add close bracket 
	inc esi					; increase buf size 
.goon:
	kernel sys_write, stdout, buf, esi	; write buf to stdout
	kernel sys_exit, 0			; exit with code 0
