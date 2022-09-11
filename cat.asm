global _start

section .text

; write_block(file: dword, data: address, bytes: dword)
write_block:
	push ebp
	mov ebp, esp

	mov ecx, [ebp+12]	; save data address
	mov edx, [ebp+16]	; save data size 
%ifdef OS_LINUX
	push ebx
	mov eax, 4	; write syscall
	mov ebx, [ebp+8]	; output descriptor
	int 80h
	pop ebx
%else
	push edx	; data size (bytes)
	push ecx	; data address
	push dword [ebp+8]	; file descriptor	
	mov eax, 4
	push eax
	int 80h
	add esp, 16
%endif
	mov esp, ebp
	pop ebp
	ret

; print_str(string: address, strlen: dword)
print_str:
	push ebp
	mov ebp, esp

	push dword [ebp+12]	; string length
	push dword [ebp+8]	; string address
	push dword 1	; standard output descriptor
	call write_block
	add esp, 12

	mov esp, ebp
	pop ebp
	ret

; read_block(file: dword, dest: address, bytes: dword)
read_block:
	push ebp
	mov ebp, esp
%ifdef OS_LINUX
	push ebx
	mov eax, 3
	mov ebx, [ebp+8]	; pass file descriptor
	mov ecx, [ebp+12]	; pass destination address
	mov edx, [ebp+16]	; pass bytes count
	int 80h	; read syscall
	pop ebx	
%elifdef OS_FREEBSD
	push dword [ebp+16]
	push dword [ebp+12]
	push dword [ebp+8]
	mov eax, 3
	push eax
	int 80h
	add esp, 16
%else
%error please define either OS_FREEBSD or OS_LINUX
%endif
	mov esp, ebp
	pop ebp
	ret

section .bss
source	resd 1
buff	resb 4096

section .text
; constants
err_arg_src	db "source file does not specified", 10
err_arg_src_s	equ $-err_arg_src
err_open_src	db "source file open error", 10
err_open_src_s	equ $-err_open_src

_start:	
	mov esi, esp
	mov ebx, [esi]	; move args count to EBX 
	cmp ebx, 1	; if args count is greater than 1
	jg .goon	; check second argument
	push dword err_arg_src_s
	push dword err_arg_src
	call print_str
	add esp, 8
	jmp .quit
.goon:	add esi, 8	; get source filename address
	; read file
%ifdef OS_LINUX
	mov eax, 5	; open syscall
	mov ebx, [esi]	; pass filename string
	mov ecx, 000h	; O_RDONLY
	int 80h
	cmp eax, fffff000h
	jl .open_dest	; check errors
%else
	push dword 000h	; O_RDONLY
	push dword [esi]	; pass filename string
	mov eax, 5	; open syscall
	push eax
	int 80h
	jc .src_open_error	; check errors
	add esp, 12
	jmp .copy
%endif
.src_open_error:
	push dword err_open_src_s
	push dword err_open_src
	call print_str
	add esp, 8
	jmp .quit

.copy:	mov [source], eax	; save source file descriptor

.again:	push dword 4096	; pass buffer size
	push dword buff	; buffer address
	push dword [source]	; source file desriptor
	call read_block
	add esp, 12	; clean stack
	mov ebx, eax	; save readed bytes
	; write buffer
	push ebx	; actual buffer size
	push dword buff	; buffer address
	call print_str 
	add esp, 8
	cmp ebx, 4096	; if read less than 4096 bytes
	jl .end_copy	; file ended
	jmp short .again	; else read next block
.end_copy:
%ifdef OS_LINUX
	mov eax, 6	; close syscall
	mov ebx, [sorce]	; source file descriptor
	int 80h	; close source file
%else
	push dword [source]
	mov eax, 6
	push eax
	int 80h
	add esp, 8
%endif
.quit:
%ifdef OS_LINUX
	mov eax, 1	; _exit syscall
	mov ebx, 0	; exit code status 0
	int 80h
%else
	push dword 0
	mov eax, 1
	push eax
	int 80h
%endif
