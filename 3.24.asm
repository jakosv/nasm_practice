%include "kernel.inc"
%include "procedure.inc"

global _start
extern stoi
extern itos
extern print_num
extern puts
extern read_num

section .bss
s	resb 100
slen	equ $-s
num	resd 1

section .text
endl	db 10
perr	db '***** stoi() parse error', 10
elen	equ $-perr
eofe	db '***** read_num() nothing to read (EOF)', 10
eofl	equ $-eofe
rner	db "***** read_num() couldn't parse char: "
rnel	equ $-rner
_start:
main:
	kernel sys_read, stdin, s, slen
					; read string
	mov ebx, eax			; EBX := read string length
	pcall stoi, s, ebx		; stoi(str, slen)
	cmp ecx, -1			; check parse error
	jne .print_first		; if ECX != -1, then parse ok
	kernel sys_write, stdout, perr, elen
	jmp .fail
.print_first:
	push eax
	pcall print_num, ecx
	kernel sys_write, stdout, endl, 1
	pop eax
	pcall itos, eax, s		; number to string
	pcall puts, s			; print sring
	kernel sys_write, stdout, endl, 1

	xor ebx, ebx 
	pcall read_num, num		; read number
	mov bl, cl
	test eax, eax			; if 0 bytes were read
	jnz .print_second
	cmp bl, -1			; if eof
	jne .not_eof
	kernel sys_write, stdout, eofe, eofl
	jmp .fail
.not_eof:
	kernel sys_write, stdout, rner, rnel
	pcall print_num, ebx
	kernel sys_write, stdout, endl, 1
	jmp short .fail
.print_second:
	pcall itos, [num], s		; number to string
	pcall puts, s			; print sring
	kernel sys_write, stdout, endl, 1

	kernel sys_exit, 0
.fail:
	kernel sys_exit, 1
