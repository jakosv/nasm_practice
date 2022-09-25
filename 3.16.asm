%include "tkernel.inc"
%include "procedure.inc"

global _start
extern getstr

section .bss
buff	resb 80
bufflen	equ $-buff
resstr	resb 81

section .text
_start:
main:
	pcall getstr, buff, bufflen	; get null-terminated string
	xor ecx, ecx			; words count = 0
	mov esi, buff			; ESI = buff address
	xor edx, edx			; word flag, EDX = 0
.again:
	mov al, [esi]			; get buff character
	cmp al, 0			; if end of string
	je .print_res			; then print result
	cmp al, 32			; if character is not space
	jne .word			; then continue reading the word
	test edx, edx			; if word flag EDX = 0
	jz .get_next			; just single space, read next
	inc ecx				; else if EDX = 1, and AL = 32
	xor edx, edx			; word ended, increase word ECX
	jmp short .get_next
.word:
	test edx, edx			; if word flag EDX = 1
	jnz .get_next			; get next character
	mov edx, 1			; else set EDX to 1
.get_next:
	inc esi				; increase current address
	jmp short .again
.print_res:
	test edx, edx			; if word flag EDX = 1
	inc ecx				; increase ECX 
	mov edx, ecx			; EDX = ECX
	mov al, '*'
	mov edi, resstr
	cld
	rep stosb			; mov ECX bytes '*' to resstr
	mov byte [resstr + edx], 10	; put null to the end of string
	inc edx
	kernel sys_write, stdout, resstr, edx 
.quit:
	kernel sys_exit, 0
