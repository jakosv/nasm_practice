%include "kernel.inc"
%include "procedure.inc"

global _start
extern read_num

section .bss
num	resd 1

section .text
rnerr	db 'Error: read number', 10
rnlen	equ $-rnerr
star	db '*'
endl	db 10

_start:
main:	pcall read_num, num	
	test eax, eax			; if 0 bytes was read
	jnz .print
	kernel sys_write, stdout, rnerr, rnlen
	kernel sys_exit, 1
.print:
	mov ebx, [num]			; if ECX = 0
.again:	
	test ebx, ebx			; if EBX = 0
	jz .end_print			; then quit
	kernel sys_write, stdout, star, 1
	dec ebx
	jmp short .again

.end_print:
	kernel sys_write, stdout, endl, 1
	kernel sys_exit, 0
