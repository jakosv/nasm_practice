%include "kernel.inc"
%include "procedure.inc"

global _start
extern print_num
extern stoi
extern is_digit

section .text
endl		db 10

; bin_pow(dd a, dd power) -> EAX
; answer a^pow is in EAX
bin_pow:
	push ebp
	mov ebp, esp
	push ebx			; save EBX

	mov ebx, [arg(1)]		; EBX := first operand
	mov eax, [arg(2)]		; EAX := second operand (power)
	cmp eax, 0			; if power = 0
	jne .goon			; if power isn't 0, goon
	mov eax, 1			; else return a^0 = 1
	jmp short .quit

.goon:
	test eax, 1			; check EAX & 1 = 1 (if EAX is odd)
	jz .even_power			; if power if even (EAX & 1 = 0)
					; calc bin_pow(n / 2) * bin_pow(n / 2)
	dec eax				; else
	pcall bin_pow, ebx, eax		; calc bin_pow(n - 1) * a
					; result of bin_pow(n-1) in EAX
	mul ebx				; bin_pow(n-1) * a 
					; a^(n-1) * a = a^n
	jmp short .quit
.even_power:
	shr eax, 1			; divide power by 2
	pcall bin_pow, ebx, eax		; result bin_pow(n/2) in EAX
	mov ebx, eax			; EBX := bin_pow(n/2) 
	mul ebx				; EAX := bin_pow(n/2) * bin_pow(n/2) 
					; a^(n/2) * a^(n/2) = a^n
.quit:
	pop ebx				; restore EBX
	mov esp, ebp
	pop ebp
	ret


; calc(dd a; dd b; db operation) -> EAX, CL
; answer in EAX
; calculation status in DL:
;	DL = 0 - good
;	DL = 1 - unknown operation
;	DL = 2 - division by zero
;	DL = 3 - negative power 
calc:	push ebp
	mov ebp, esp
	push ebx			; save EBX to stack

	mov eax, [arg(1)]		; prepare first operand
	mov ebx, [arg(2)]		; prepare second operand
	mov dl, [arg(3)]		; DL := operation char

	cmp byte dl, '+'
	je .add
	cmp byte dl, '-'
	je .sub
	cmp byte dl, '*'
	je .mul
	cmp byte dl, '^'
	je .pow
	cmp byte dl, '/'
	je .div
	cmp byte dl, '%'
	je .div
	mov dl, 1
	jmp .quit

.div:	xor edx, edx			; put 0 in EDX
	mov ebx, ebx
	test ebx, ebx			; if the divisor is 0
	jnz .not_zero
	mov dl, 2			; error status 2
	jmp .quit

.not_zero:
	cdq				; copy sign bit to each bit in EDX
	idiv ebx			; quotient of division is in EAX
					; remainder is in EDX
	cmp byte [arg(3)], '%'
	jne .div_end
	mov eax, edx			; return remainder of division
.div_end:
	jmp .end_calc

.add:	add eax, ebx
	jmp .end_calc

.sub:	sub eax, ebx
	jmp .end_calc

.mul:	imul eax, ebx
	jmp .end_calc

.pow:	cmp ebx, 0			; if power is not less than 0
	jnl .goon_pow			;	then go on
	mov dl, 3
	jmp short .quit
.goon_pow:
	pcall bin_pow, eax, ebx		; push second operand (power)

.end_calc:
	mov dl, 0			; return good calculation status
.quit:	
	pop ebx				; restore EBX
	mov esp, ebp
	pop ebp
	ret

; get_priority(db operator) -> AL
; result in AL 
get_priority:
	push ebp
	mov ebp, esp
	
	mov dl, [arg(1)]	; DL := operator

.plus:	cmp dl, '+'
	jne .minus
	mov al, 1
	jmp short .quit
.minus:	cmp dl, '-'
	jne .mul
	mov al, 1
	jmp short .quit
.mul:	cmp dl, '*'
	jne .div
	mov al, 2
	jmp short .quit
.div:	cmp dl, '/'
	jne .remainder
	mov al, 2
	jmp short .quit
.remainder:	
	cmp dl, '%'
	jne .pow
	mov al, 2
	jmp short .quit
.pow:	cmp dl, '^'
	jne .quit
	mov al, 3

.quit:	mov esp, ebp
	pop ebp
	ret

; is_operator(db character) -> AL
; if character is operator then 
;	EAX := 1
; else 
;	EAX := 0
is_operator:
	push ebp
	mov ebp, esp
	
	cmp byte [arg(1)], '+'
	je .true
	cmp byte [arg(1)], '-'
	je .true
	cmp byte [arg(1)], '*'
	je .true
	cmp byte [arg(1)], '/'
	je .true
	cmp byte [arg(1)], '%'
	je .true
	cmp byte [arg(1)], '^'
	je .true

	jmp short .false	; otherwise false

.false:	xor eax, eax
	jmp short .quit

.true:	mov eax, 1

.quit:	mov esp, ebp
	pop ebp
	ret

; push_operand(dd stack_addr, dd operand)
; the first 4 bytes on stack are stack size
push_operand:
	push ebp
	mov ebp, esp

	push esi
	
	mov edx, [arg(1)]	; ECX := stack address
	mov eax, [arg(2)]	; EAX := operand
	mov ecx, [edx]		; ECX := stack size (first 4 bytes)

	lea esi, [4+edx+4*ecx]	; calculate address before last element
				; skip 4 bytes of stack size memory + 
				;	4*(elements count) bytes 

	mov [esi], eax		; push new operand
	inc dword [edx]		; increase stack size

	pop esi
	mov esp, ebp
	pop ebp
	ret

; pop_operand(dd stack_addr) -> EAX
; return operand in EAX
; the first 4 bytes on stack are stack size
pop_operand:
	push ebp
	mov ebp, esp

	push esi
	
	mov edx, [arg(1)]	; ECX := stack address
	mov ecx, [edx]		; ECX := stack size (first 4 bytes)

	lea esi, [4+edx+4*ecx-4]	
				; calculate address of last element
				; skip 4 bytes of stack size memory
				; skip 4*(elements count - 1) bytes 

	mov eax, [esi]		; pop operand
	dec dword [edx]		; decrease stack size

	pop esi
	mov esp, ebp
	pop ebp
	ret

; calc_operands(dd stack_addr, db operator)
calc_operands:
	push ebp
	mov ebp, esp

	push esi
	push edi
	push ebx
	
	mov edi, [arg(1)]	; ECX := stack address
	mov ecx, [edi]		; ECX := stack size (first 4 bytes)

	lea esi, [4+edi+4*ecx-4]	
				; calculate address of last element
				; skip 4 bytes of stack size memory
				; skip 4*(elements count-1) bytes 

	mov ebx, [esi]		; pop second operand
	sub esi, 4		; previous operand address
	mov ecx, [esi]		; pop first operand
	mov al, byte [arg(2)]	; AL := operator
	pcall calc, ecx, ebx, eax

	mov [esi], eax		; save calculation result
	dec dword [edi]		; decrease stack size

	pop ebx
	pop edi
	pop esi

	mov esp, ebp
	pop ebp
	ret

; push_operator(dd stack_addr, db operator)
; the first 4 bytes on stack are stack size
push_operator:
	push ebp
	mov ebp, esp

	push esi
	
	mov edx, [arg(1)]	; ECX := stack address
	mov al, byte [arg(2)]	; AL := operator 
	mov ecx, [edx]		; ECX := stack size (first 4 bytes)

	lea esi, [4+edx+ecx]	; calculate address before last element
				; skip 4 bytes of stack size memory
				; skip (elements count) bytes 

	mov byte [esi], al	; push new operator 
	inc dword [edx]		; increase stack size

	pop esi
	mov esp, ebp
	pop ebp
	ret

; pop_operator(dd stack_addr) -> AL
; return operator in AL
; the first 4 bytes on stack are stack size
pop_operator:
	push ebp
	mov ebp, esp

	push esi
	
	mov edx, [arg(1)]	; ECX := stack address
	mov ecx, [edx]		; ECX := stack size (first 4 bytes)

	lea esi, [4+edx+ecx-1]	; calculate address before last element
				; skip 4 bytes of stack size memory
				; skip (elements count - 1) bytes 

	mov al, byte [esi]	; pop operator 
	dec dword [edx]		; decrease stack size

	pop esi
	mov esp, ebp
	pop ebp
	ret

; top_operator(dd stack_addr) -> AL
; return top operator on stack in AL
top_operator:
	push ebp
	mov ebp, esp

	mov edx, [arg(1)]	; ECX := stack address
	mov eax, [edx]		; ECX := stack size (first 4 bytes)

	lea ecx, [4+edx+eax-1]	; calculate address of last element
				; skip 4 bytes of stack size memory
				; skip (elements count - 1) bytes 

	mov al, byte [ecx]	; return top operator

	mov esp, ebp
	pop ebp
	ret

; stack_size(dd stack_addr) -> EAX
; return value of stack size in EAX
stack_size:
	push ebp
	mov ebp, esp

	mov edx, [arg(1)]	; ECX := stack address
	mov eax, [edx]		; ECX := stack size (first 4 bytes)

	mov esp, ebp
	pop ebp
	ret


; calc_expr(dd expr_addr, dd expr_len) -> EAX, CL
; answer is in EAX
; CL is 0 if there were no errors, otherwise 1

; constants
parse_err	db "ERROR: can't parse expression, character '"
perrlen		equ $-parse_err
err_pos		db "' in position "
eposlen		equ $-err_pos
close_err	db "ERROR: too much close brackets", 10
cerrlen		equ $-close_err
open_err	db "ERROR: too much open brackets", 10
oerrlen		equ $-open_err

calc_expr:
	push ebp
	mov ebp, esp

	mov edx, [arg(2)]		; EDI := expression string length
	lea eax, [edx + 4]
	xor edx, edx
	shr eax, 2			; EAX := EAX // 4
	shl eax, 2			; EAX := EAX * 4 
					; EAX := ((EAX + 4) // 4) * 4
	sub esp, eax			; memory for operators stack
	lea edx, [eax * 4]		; memory for operands stack
	sub esp, edx 
	sub esp, 12			; 3 local variables (dword)
	
	push ebx			; save EBX
	push esi
	push edi


	lea ebx, [local(3) - 4]		; skip local variables memory
	sub ebx, eax			; skip operators stack memory
	mov [local(2)], ebx
	mov dword [ebx], 1		; operators stack size
	add ebx, 4			; skip operators stack size memory
	mov byte [ebx], '('		; push open bracket to stack
	lea ebx, [local(3) - 4]		; skip local variables memory
	sub ebx, eax			; skip operators stack memory
	sub ebx, edx			; skip operands stack memory
	mov [local(3)], ebx		; operands stack pointer
	mov dword [ebx], 0		; operands stack size := 0

	mov esi, [arg(1)]		; ESI := expression string address
	mov edi, [arg(2)]
	xor ebx, ebx

	mov byte [local(1)], -1		; last character flag:
					;     -1 - it's first character
					;     0 - digit
					;     1 - operator


.read:
	test edi, edi			; if expression string length = 0
	jz .end_read			; quit
	mov bl, [esi]
	cmp bl, 9			; if TAB character
	je .next_char
	cmp bl, 32			; if SPACE character
	je .next_char

	pcall is_digit, ebx		; if is_digit(BL) (EAX = 1)
	test eax, eax			; if EAX = 0
	jz .not_digit
	cmp byte [local(1)], 0		; if last char is digit
	jne .operand			; if not - okay
	jmp .parse_err			; else parse error
.operand:
	pcall stoi, esi, edi
	add esi, ecx			; skip processed characters
	sub edi, ecx			; decrease string size
	pcall push_operand, [local(3)], eax
	mov byte [local(1)], 0		; set last character flag to digit
	jmp .read			; read next character

.not_digit:
	cmp bl, ')'
	jne .not_close
	cmp byte [local(1)], 0		; if last character was a digit
	jne .parse_err			; if it's not, then error
.search_open:
	pcall stack_size, [local(2)]	; if operators stack is empty
	test eax, eax
	jz .close_err			; open bracket not found

	pcall pop_operator, [local(2)]	; result in EAX
	cmp al, '('			; if AL = '('
	je .open_found			; open bracket found

	pcall calc_operands, [local(3)], eax	
					; perform operation

	jmp short .search_open		; else continue search
.open_found:
	mov byte [local(1)], 0		; set last character flag to digit
	jmp .next_char

.not_close:
	cmp bl, '('
	jne .not_open
	pcall push_operator, [local(2)], ebx	
					; push open bracket to operators stack
	jmp .next_char

.not_open:
	pcall is_operator, ebx		; if is_operator(BL) (EAX = 1)
	test eax, eax			; if EAX = 0 (not operator)
	jz .parse_err			; then parse error
	cmp byte [local(1)], 0		; if last char was a digit
	je .binary_oper
	cmp bl, '-'			; if char is unary minus
	jne .parse_err			; if it isn't, then error
	pcall push_operand, [local(3)], 0
					; push 0 operand to operands stack
					; to make it binary operator
.binary_oper:
	mov byte [local(1)], 1		; set last character flag to operator 
	pcall get_priority, ebx		; get current operator priority
	mov bh, al			; BH := character priority
.pop_operators:
	pcall stack_size, [local(2)]	; if operators stack is empty
	test eax, eax			; if empty (EAX = 0)
	jz .close_err			; empty stack error 
	pcall top_operator, [local(2)]	; AL := operator
	cmp al, '('			; if open bracket
	je .push_operator		; just push operator

	pcall get_priority, eax		; get AL opertor priority (in EAX)
	cmp bh, al			; compare operators priority
	jg .push_operator

	pcall pop_operator, [local(2)]	; poped operator is in AL
	pcall calc_operands, [local(3)], eax
	jmp short .pop_operators	; continue
.push_operator:
	pcall push_operator, [local(2)], ebx
					; save operator to stack

.next_char:
	dec edi				; descrease expression string size
	inc esi				; next char address
	jmp .read

.end_read:
.clean_stack:
	pcall stack_size, [local(2)]	; stack size in EAX
	test eax, eax			; if EAX = 0
	jz .close_err			; empty stack error 

	pcall pop_operator, [local(2)]
	cmp al, '('			; if open bracket
	je .end_clean			; stack is empty

	pcall calc_operands, [local(3)], eax
	jmp short .clean_stack		; continue
.end_clean:
	pcall stack_size, [local(2)]	; stack size in EAX
	test eax, eax			; if EAX != 0
	jnz .open_err			; open brackets error

	pcall stack_size, [local(3)]	; if there isn't operands on stack
	test eax, eax			; if stack is empty, EAX = 0
	jnz .not_empty			; then quit
	mov eax, 0
	mov cl, 0
	jmp .quit
.not_empty:
	pcall pop_operand, [local(3)]	; operand in EAX
	mov cl, 0
	jmp .quit

.parse_err:
	kernel sys_write, stdout, parse_err, perrlen
	kernel sys_write, stdout, esi, 1
	kernel sys_write, stdout, err_pos, eposlen 
	mov edx, [arg(2)]		; expression string length
	sub edx, edi			; current character position
	inc edx				; set numeration from 1
	pcall print_num, edx
	kernel sys_write, stdout, endl, 1
	mov cl, 1
	jmp short .quit

.close_err:
	kernel sys_write, stdout, close_err, cerrlen
	mov cl, 1
	jmp short .quit

.open_err:
	kernel sys_write, stdout, open_err, oerrlen
	mov cl, 1

.quit:
	pop edi
	pop esi
	pop ebx				; restore EBX
	mov esp, ebp
	pop ebp
	ret

section .bss
expr	resb 1000
char	resb 1

section .text
_start:
main:
	xor ebx, ebx
	mov edi, expr
.read_char:
	kernel sys_read, stdin, char, 1 
	test eax, eax			; if end of file
	jz .end_read
	mov al, [char]
	cmp al, 10			; if carriage return
	je .print_res

	inc ebx				; increase string size
	mov [edi], al			; save character
	inc edi				; next string address
	jmp short .read_char

.print_res:
	pcall calc_expr, expr, ebx
	xor ebx, ebx			; string size := 0
	mov edi, expr			; EDI := first character address
	test cl, cl			; if there were an errors
	jnz .read_char			; skip printing result
	pcall print_num, eax
	kernel sys_write, stdout, endl, 1
	jmp .read_char
	
.end_read:
	test ebx, ebx			; if expression size is 0
	jz .goon
	pcall calc_expr, expr, ebx
	test cl, cl			; if there were an errors
	jnz .goon			; skip printing result
	pcall print_num, eax
	kernel sys_write, stdout, endl, 1
.goon:
	kernel sys_exit, 0
