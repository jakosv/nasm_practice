%include "kernel.inc"
%include "procedure.inc"

global _start

section .bss
char	resb 1
eof	resb 1
buf	resb 4096

section .text

_start:
main:
	xor esi, esi			; buf size
	mov byte [eof], 0
.get_line:
	push dword 0			; push zero \0 to stack
	mov ebx, 2			; current bit in dword
.read_char:
	kernel sys_read, stdin, char, 1
	test eax, eax			; if 0 bytes were read
	jnz .not_eof
	mov byte [eof], 1
	jmp short .save_line
.not_eof:
	mov al, [char]
	cmp al, 10			; if caret return
	je .save_line
	cmp ebx, 3			; if we work with last byte of dword 
	jne .cur_dword
	push dword 0			; allocate new dword on stack
.cur_dword:
	mov [esp + ebx], al		; put byte in dword
	dec ebx				; next byte position
	and ebx, 11b			; EBX := (EBX - 1) % 4
	jmp short .read_char

.save_line:
	inc ebx				; last added byte position
	and ebx, 11b			; EBX := (EBX + 1) % 4
	test ebx, ebx			; if it's last byte of dword
	jnz .goon
	pop edx				; pop dword from stack
.goon:
	mov al, [esp + ebx]
	cmp al, 0
	jne .not_end
	cmp byte [eof], 1
	je .print_res
	mov byte [buf + esi], 10
	inc esi
	jmp short .get_line 
.not_end:
	mov [buf + esi], al
	inc esi 
	jmp short .save_line
.print_res:
	kernel sys_write, stdout, buf, esi	

.quit:	kernel sys_exit, 0
