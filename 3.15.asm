%include "kernel.inc"
global _start

section .bss
chr resb 1

section .text
syes db 'YES', 10
syeslen equ $-syes
sno db 'NO', 10
snolen equ $-sno
rerr db '*****Error: unknown chracter', 10
rerrlen equ $-rerr

_start:	xor ebx, ebx	; erase balance counter
.getch: kernel sys_read, stdin, chr, 1	; read character
	test eax, eax	; if read 0 bytes
	jz .answ	; print answer
	cmp byte [chr], 10	; check caret return
	je .answ
	cmp byte [chr], '('	; else process character
	jne .close
	inc ebx	; increase balance
	jmp short .getch
.close:	cmp byte [chr], ')'
	jne .read_err	; unknown character error
	dec ebx	; decrease balance
	jmp short .getch	; get next char
.answ:	test ebx, ebx	; if balance is 0
	jnz .no
	kernel sys_write, stdout, syes, syeslen
	jmp short .quit
.no:	kernel sys_write, stdout, sno, snolen
.quit:	kernel sys_exit, 0
.read_err:
	kernel sys_write, stdout, rerr, rerrlen
	kernel sys_exit, 1

