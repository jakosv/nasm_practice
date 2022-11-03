%include "kernel.inc"
%include "procedure.inc"

global print_num

; print_num(number: dd)
print_num:
	push ebp
	mov ebp, esp
	sub esp, 4			; local(1) - number sign flag

	push ebx			; save ebx
	push esi
	push edi
	
	mov ebx, 10			; EBX := 10 (base)
	xor ecx, ecx			; ECX := 0 (number length counter)
	mov eax, [arg(1)]
	mov byte [local(1)], 0		; set sign flag to 0
	mov edi, 3			; byte position in dword
	xor esi, esi			; dwords count

	mov edx, 1
	shl edx, 31			; EDX := 2^31
	test eax, edx			; if EAX is not negative number 
	jz .get_digit			; then skip adding minus
	mov byte [local(1)], 1		; set sign flag to 1
	neg eax				; EAX := -EAX
		
.get_digit:
	xor edx, edx
	div ebx				; EAX := EAX div 10
	add edx, '0'			; convert EDX to char
	cmp edi, 3			; if last byte position
	jne .push_byte
	push dword 0			; allocate new dword on stack
	inc esi				; increase dwords count
.push_byte:
	mov [esp + edi], dl		; mov digit byte
	mov edx, edi
	add edx, '0'
	dec edi				; get next byte
	and edi, 11b			; EDI := EDI % 4 (dword = 4 bytes)
	inc ecx				; increase counter
	test eax, eax			; if EAX != 0
	jnz .get_digit			; then get next digit
	
	; reverse number string
	lea ebx, [esi * 4]		; save size of allocated memory
	mov esi, esp			; ESI := first dword address
	inc edi				; get last byte position
	and edi, 11b			; EDI := EDI % 4 (dword = 4 bytes)
	add esi, edi			; get first byte address
	
	cmp byte [local(1)], 1		; if sign flag is not 1
	jne .print_res			; then print number
	test edi, edi			; if there is place in curr dword
	jnz .curr_dword			; mov minus char to current dword
	push dword 0			; allocate dword on stack
.curr_dword:
	dec esi
	mov byte [esi], '-'
	inc ecx				; increase chars count
.print_res:
	kernel sys_write, stdout, esi, ecx

.quit:	add esp, ebx			; free allocated memory on stack	
	pop edi
	pop esi
	pop ebx				; restore ebx
	mov esp, ebp
	pop ebp
	ret
