%include "kernel.inc"
%include "procedure.inc"

global _start
extern stoi
extern print_num

section .bss
s	resb 100
slen	equ $-s

section .text
endl	db 10
perr	db '***** stoi() parse error', 10
elen	equ $-perr
_start:
main:
	kernel sys_read, stdin, s, slen
					; read string
	mov ebx, eax			; EBX := read string length
	pcall stoi, s, ebx		; stoi(str, slen)
	test cl, cl			; check parse error
	jz .print_num			; if CL = 0, then parse ok
	kernel sys_write, stdout, perr, elen
	kernel sys_exit, 1
.print_num:
	pcall print_num, eax		; print result number
	kernel sys_write, stdout, endl, 1

	kernel sys_exit, 0
