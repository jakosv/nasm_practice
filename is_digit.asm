%include "procedure.inc"

global is_digit

section .text

; is_digit(char: db): EAX (0 - false, 1 - true)
is_digit:
	push ebp
	mov ebp, esp

	mov al, byte [arg(1)]
	cmp al, '0'			; if EDX < '0'
	jl .false			;	return false
	cmp al, '9'			; if EDX > '9'
	jg .false			;	return false
					; else
	mov eax, 1			;	return true
	jmp short .quit
.false:	xor eax, eax
.quit:	mov esp, ebp
	pop ebp
	ret
