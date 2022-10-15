%include "kernel.inc"
%include "procedure.inc"

extern read_num
extern print_num
global _start

section .text
; calc(db operation; dd a, b): EAX, ECX
; the result of operation in EAX
; operation status in ECX (0 - good, 1 - error)
calc:	
	push ebp
	mov ebp, esp
	push ebx		; save register
	
	mov edx, [arg(1)]	; EDX := operation character
	mov eax, [arg(2)]	; EAX := first operand (a)
	mov ebx, [arg(3)]	; ECX := second operand (b)
	xor ecx, ecx		; operation status := 0 (good by default)

	cmp dl, '-'
	jne .plus
	sub eax, ebx
	jmp short .quit

.plus:	cmp dl, '+'
	jne .mul
	add eax, ebx
	jmp short .quit

.mul:	cmp dl, '*'
	jne .div
	imul ebx
	jmp short .quit

.div:	cmp dl, '/'
	jne .error
	xor edx, edx		; prepare EDX for division
	idiv ebx
	jmp short .quit

.error:	mov ecx, 1		; operation status := 1 (error)

.quit:	pop ebx			; restore register
	mov esp, ebp
	pop ebp
	ret

; is_operator(db char): EAX
; EAX := 1 - if char is operator, 0 - otherwise
is_operator:
	push ebp
	mov ebp, esp
	
	mov eax, [arg(1)]

	cmp al, '+'
	jne .minus
	jmp short .true

.minus:	cmp al, '-'
	jne .mul
	jmp short .true

.mul:	cmp al, '*'
	jne .div
	jmp short .true

.div:	cmp al, '/'
	jne .false
	jmp short .true

.false:	xor eax, eax
	jmp short .quit
.true:	mov eax, 1

.quit:
	mov esp, ebp
	pop ebp
	ret

section .bss
a	resd 1
b	resd 1
res	resd 1
op	resb 1

section .text
; constants
endl	db 10
foperr	db "Error: invalid first operand", 10
foplen	equ $-foperr
soperr	db "Error: invalid second operand", 10
soplen	equ $-soperr
operr	db "Error: invalid operation (use: +, -, *, /)", 10
oplen	equ $-operr
; code
_start:
main:
.read_expr:
	pcall read_num, a		; read first operand
	cmp ecx, -1			; if EOF situation (ECX = -1)
	je .end_read

	test eax, eax			; if was read 0 characters	
	jz .foperr

	mov [op], cl
	pcall is_operator, ecx		; check if char after first operand
	test eax, eax			; is operator
	jnz .second_operand
	
.read_operator:
	kernel sys_read, stdin, op, 1	; read operation character
	test eax, eax			; if read 0 bytes
	jz .end_read

	cmp byte [op], ' '		; if space character
	je .read_operator		; read char again

	pcall is_operator, [op]		; is_operator(op)
	test eax, eax			; if EAX = 0 (not operator)
	jz .operr			; print error

.second_operand:
	pcall read_num, b		; read second operand
	cmp ecx, -1			; if EOF situation (ECX = -1)
	je .end_read

	test eax, eax			; if was read 0 characters	
	jz .soperr

	pcall calc, [op], [a], [b]
	pcall print_num, eax
	kernel sys_write, stdout, endl, 1
	jmp .read_expr

.foperr:
	kernel sys_write, stdout, foperr, foplen 
	jmp short .clean_buf
.soperr:
	kernel sys_write, stdout, soperr, soplen 
	jmp short .clean_buf
.operr:
	kernel sys_write, stdout, operr, oplen 
.clean_buf:
	kernel sys_read, stdin, op, 1
	cmp eax, 0			; if can't read 
	je .end_read			; then cleaning done
	cmp byte [op], 10		; if char isn't caret return
	jne .clean_buf			; continue cleaning

	jmp .read_expr

.end_read:
	kernel sys_exit, 0


