%include "kernel.inc"
%include "procedure.inc"

global read_num
extern is_digit

section .text

; read_num(number: address): EAX, CL
; EAX contains number of characters
; CL contains the last read char or -1 if end-of-file (EOF)
read_num:
	push ebp
	mov ebp, esp
	sub esp, 12			; local(1) - temp char
	mov dword [local(2)], 10	; local(2) := 10 (base)
	mov byte [local(3)], 0		; local(3) number sign (0 - plus)

	lea esi, [local(1)]		; ESI := local(1) address
	xor ebx, ebx			; EBX = 0 - number length 
	xor edi, edi			; EDI = 0 - result number

.read_spaces:
	kernel sys_read, stdin, esi, 1	; read sign from stdin
	test eax, eax			; if 0 bytes were read
	jz .eof				; then quit
	
	cmp byte [esi], 32		; if space (32 - ascii code)
	je .read_spaces			; then read char again

	cmp byte [esi], 9		; if tab (9 - ascii code)
	je .read_spaces			; then read char again

	mov al, [esi]
	cmp al, '-'			; if character is minus
	jne .check_plus			; if it isn't, then process char 
	mov byte [local(3)], 1		; set sign flag
	jmp short .read_digit		; and go to read first digit
.check_plus:
	cmp al, '+'			; if character is plus
	jne .skip_read			; if it isn't, then process char 

.read_digit:
	kernel sys_read, stdin, esi, 1	; read character from stdin
.skip_read:
	test eax, eax			; if 0 bytes were read
	jz .eof				; end of file, quit

	pcall is_digit, [esi]		; check if character is digit
	test eax, eax			; if EAX = 0 (false)
	jz .not_digit			;	then quit
					; else add digit to number
	mov eax, edi
	xor edx, edx
	mul dword [local(2)]		; EAX := EAX * 10

	mov edx, [esi]			; EDX := digit
	sub edx, '0'			; EDX := EDX - '0'
	add eax, edx			; EAX := EAX + EDX
	mov edi, eax			; EDI := EAX * 10 + digit
	inc ebx				; increase nubmer length
	jmp short .read_digit		; read next char

.eof:	mov ecx, -1			; ECX := -1 (EOF situation)
	jmp short .end_read
.not_digit:
	mov ecx, [esi]

.end_read:
	test ebx, ebx			; if number length = 0
	jz .skip_save			; skip saving number
	cmp byte [local(3)], 1		; if number sign is minus
	jne .plus
	neg edi
	inc ebx
.plus:
	mov esi, [arg(1)]		; ESI := number address
	mov [esi], edi			; save number 
.skip_save:
	mov eax, ebx			; return number length

	mov esp, ebp
	pop ebp
	ret
