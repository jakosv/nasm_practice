%include "kernel.inc"

global _start
extern quit

section .text

section .bss
source resd 1
dest resd 1
argc resd 1
argvp resd 1
buff resb 4096
buffsize equ $-buff

section .text
; constants
helpmsg	db "Usage: copy <src> <dest>", 10
helplen equ $-helpmsg
err1msg db "Couldn't open source file for reading", 10
err1len equ $-err1msg
err2msg db "Couldn't open destination file for writing", 10
err2len	equ $-err2msg
%ifdef OS_LINUX
openwr_flags	equ 241h
%else
openwr_flags	equ 601h
%endif

main:
_start:
	pop dword [argc]	; save arguments
	mov [argvp], esp
	cmp dword [argc], 3	; if args count is 3
	je .args_cnt_ok
	; print error with write syscall in error output
	kernel 4, 2, helpmsg, helplen 
	kernel 1, 1	; exit with error code 2
.args_cnt_ok:
	mov esi, [argvp]	; get source filename address
	mov edi, [esi+4]
	; open source file for reading
	kernel 5, edi, 0	; open syscall
	cmp eax, -1
	jne .src_open_ok
	; print error with write syscall in error output
	kernel 4, 2, err1msg, err1len
	kernel 1, 2	; exit with error code 1
.src_open_ok:
	mov [source], eax	; save source file descriptor
	mov esi, [argvp]	; get destination filename address
	mov edi, [esi+8]
	; open destintation file for writing
	kernel 5, edi, openwr_flags, 0666q
	cmp eax, -1
	jne .copy		; check error
	; print error with write syscall in error output
	kernel 4, 2, err2msg, err2len
	kernel 1, 3	; exit with error code 2

.copy:	mov [dest], eax	; get destination file descriptor
	; read buffer from source file
.again:	kernel 3, [source], buff, buffsize	; read syscall
	cmp eax, 0	; check end of file situation
	je .end_copy
	; write buffer to destination file
	kernel 4, [dest], buff, eax	; write syscall
	jmp short .again	; else read next block
.end_copy:
	; close syscall
	kernel 6, [source]	; close source file
	kernel 6, [dest]	; close destination file
	kernel 1, 0	; exit with normal code 0
