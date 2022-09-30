%include "kernel.inc"
%include "procedure.inc"

global _start

section .text

; read_word(address) -> EAX, ECX
; EAX := string status (0 default, -1 if end of line, -2 if end of file)
; ECX := word length
read_word:
	push ebp
	mov ebp, esp
	sub esp, 8				; local(1) - temp char 
	push ebx				; save EBX
	mov byte [local(2)], 0			; local(2) - flag
	mov edi, [arg(1)]			; EDI := string address
	xor ebx, ebx				; ECX := 0 (word length)
	lea esi, [local(1)]			; ESI := char address

.read_char:
	kernel sys_read, stdin, esi, 1		; read(char)
	test eax, eax				; if EAX = 0 (0 bytes)
	jz .eof					; end of file sutiation
	mov al, [esi]				; AL := read char
	cmp al, 10				; if end of line
	je .end_line				; quit 
	cmp al, 9				; if AL = tab 
	jne .check_space	
	cmp byte [local(2)], 1			; if wasn't word
	jne .read_char				; continue reading
	jmp short .end_read			; quit
.check_space:
	cmp al, 32				; if AL = space
	jne .char				; normal char
	cmp byte [local(2)], 1			; if wasn't word
	jne .read_char				; continue reading
	jmp short .end_read			; else quit
.char:
	mov [edi + ebx], al			; else save char
	inc ebx					; increase length
	mov byte [local(2)], 1			; set flag word was
	jmp .read_char			; read next char

.end_line:
	mov eax, -1				; EAX := -1
	jmp short .quit
.eof:	mov eax, -2				; EAX := -2
	jmp short .quit
.end_read:
	mov eax, 0				; EAX := 0
.quit:	mov ecx, ebx	
	pop ebx					; restore EBX	
	mov esp, ebp	
	pop ebp
	ret

section .bss
buf	resb 4096				; temp line buffer
wstr	resb 128				; temp word buffer
first	resb 1					; first word flag

section .text
_start:
main:
	xor ebx, ebx				; EBX := 0 (buf index)
	mov byte [first], 1			; set first word flag := 1
.read_next:	
	pcall read_word, wstr			; read word
	test ecx, ecx				; if was read 0 bytes
	jz .skip_copy				; then skip add word
	cmp byte [first], 0			; if it's not first word
	jne .first
	mov byte [buf + ebx], ' '		; insert space separator 
	inc ebx					; increase index
	jmp short .copy
.first:	mov byte [first], 0			; else set flag := 0
.copy:	mov byte [buf + ebx], '('		; insert open bracket
	inc ebx
	mov esi, wstr				; ESI := word address
	lea edi, [buf + ebx]			; EDI := buf address
						; ECX := word length
	mov edx, ecx
	cld
	rep movsb				; copy word to buf
	add ebx, edx				; increase buf index
	mov byte [buf + ebx], ')'		; insert close bracket
	inc ebx					; increase index
.skip_copy:
	cmp eax, -2				; if end of file
	je .end_read				; stop reading
	cmp eax, -1				; if it's not end of line
	jne .read_next				; read next word 
						; else print line
	mov byte [buf + ebx], 10		; add '\n' char
	inc ebx
	kernel sys_write, stdout, buf, ebx	; write buf to stdout

	xor ebx, ebx				; EBX := 0 (clear buf)
	mov byte [first], 1			; set first word flag := 1
	jmp .read_next				; read next char

.end_read:
	kernel sys_exit, 0			; exit with code 0
