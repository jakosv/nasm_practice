%include "kernel.inc"
%include "procedure.inc"

global stoi
extern is_digit

section .text

; stoi(dd str_addr, dd length) -> EAX, ECX
; EAX - result decemical number
; ECX - the number of character processed, or -1 if was an error
stoi:
	push ebp
	mov ebp, esp
	sub esp, 4		; local(1)
	push esi		; save ESI value
	push edi		; save ESI value
	push ebx		; save EBX value

	mov esi, [arg(1)]	; ESI := string address
	mov ecx, [arg(2)]	; ECX := string length
	mov ebx, 10		; radix
	mov byte [local(1)], 0	; flag (was digit) := 0
	mov byte [local(1) + 1], 0	
				; number sign (0 - plus, 1 - minus) 
	xor edi, edi		; result number

.trim:
	jcxz .parse_err		; if end of string (ECX = 0), then quit
	mov al, [esi]		; AL := current string character
	cmp al, 32		; if space
	je .trim_next
	cmp al, 9		; if tab char
	je .trim_next
	cmp al, 10		; if caret return char
	jne .read_sign
.trim_next:
	inc esi
	loop .trim

.read_sign:
	jcxz .parse_err		; if end of string (ECX = 0), then quit
	mov al, [esi]		; AL := current string character
	cmp al, '-'
	jne .check_plus
	mov byte [local(1) + 1], 1	; set sign flag to 1
	jmp short .process_sign
.check_plus:
	cmp al, '+'
	jne .read_char
.process_sign:
	inc esi
	dec ecx
	
.read_char:
	jcxz .end_read		; if end of string (ECX = 0), then quit
	xor eax, eax		; EAX := 0
	mov al, [esi]		; AL := current string character

	push eax		; save EAX value
	push ecx		; save ECX value
	pcall is_digit, eax	; is_digit(AL) (AL = 1 - digit)
	test eax, eax		; EAX = 1 (it's digit)
	pop ecx			; restore ECX
	pop eax			; restore EAX value
	jz .end_read		; if it isn't digit (AL=0), end reading 
	mov byte [local(1)], 1	; set was digit flag to 1
	sub al, '0'		; char to number
	push eax		; save digit
	mov eax, edi		; prepare EAX for multiplication
	imul ebx		; EAX := EAX * 10
	pop edx			; DL := current digit saved on stack
	add eax, edx		; EAX := EAX + digit
	mov edi, eax		; save result number to EDI
	
	inc esi			; next address
	loop .read_char		; dec ECX, and read next char

.end_read:
	cmp byte [local(1)], 1	; if there was at least one digit
	je .parse_ok		; then return number
				; else print parse error
.parse_err:
	mov ecx, -1
	jmp short .quit

.parse_ok:
	mov eax, [arg(2)]	; EAX := string length
	sub eax, ecx		; count the number of processed characters
	mov ecx, eax		; return count
	cmp byte [local(1) + 1], 1
				; if sign is minus
	jne .goon
	neg edi
.goon:
	mov eax, edi		; EAX := result number

.quit:
	pop ebx
	pop edi
	pop esi
	mov esp, ebp
	pop ebp
	ret
