%include "kernel.inc"
%include "procedure.inc"

global _start
extern print_num

section .bss
cnt	resd 1
char	resb 1

section .text
endl	db 10
_start:
main:
	mov dword [cnt], 0			; cnt := 0
.read_data:
	kernel sys_read, stdin, char, 1
	test eax, eax				; if 0 bytes was read
	jz .print_res				; print result
	add [cnt], eax				; cnt := cnt + read bytes
	jmp short .read_data

.print_res:
	pcall print_num, [cnt]
	kernel sys_write, stdout, endl, 1
	kernel sys_exit, 0
