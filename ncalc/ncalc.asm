%macro PUTCHAR 1
	pushf
	pusha
	push esi	; save ESI
	push eax

	mov al, %1

	push eax
	mov esi, esp

	; syscall write
  %ifdef OS_FREEBSD
	push dword 1	; data length
	push dword esi	; data
	push dword 1	; 1 - standard output	
	mov eax, 4	; syscall write number - 4
	push eax	; anything
	int 0x80	; make syscall
	add esp, 16	; clear stack
  %else
	mov eax, 4
	mov ebx, 1
	mov ecx, esi
	mov edx, 1
	int 0x80
  %endif

	add esp, 4	; clear ESI data

	pop eax
	pop esi	; restore ESI
	popa
	popf
%endmacro

%macro PRINT 1
  %ifnstr %1
    %error %1 is not string 
  %else
    %strlen len %1
	push esi	; save ESI
	pusha
	pushf

	mov esi, esp
      %assign dwords_count (len + 4 - 1) // 4
	sub esi, 4 * dwords_count
    %rep dwords_count 
	push dword 0	; reserve stack memory
    %endrep
    %assign pos 1
    %rep len
      %substr char %1 pos
	mov byte [esi + pos - 1], char	; move char to stack 
      %assign pos pos+1
    %endrep
	; syscall write
    %ifdef OS_FREEBSD
	push dword len	; pass string length
	push esi	; pass string address
	push dword 1	; 1 - standard output
	mov eax, 4	; write syscall number - 4 
	push eax	; anything
	int 0x80	; make syscall
	add esp, 16 	; clean stack
    %else
	mov eax, 4
	mov ebx, 1
	mov ecx, esi
	mov edx, len
	int 0x80
    %endif

	add esp, 4 * dwords_count
	popf
	popa
	pop esi	; restore ESI
  %endif
%endmacro

%macro GETCHAR 0
	pusha
	pushf
	push ebx	; save EBX

	sub esp, 4	; data memory
	mov ebx, esp

	;syscall read 
  %ifdef OS_FREEBSD
	push dword 1	; data length
	push ebx	; data address
	push dword 0	; standard input descriptor - 0
	mov eax, 3	; read syscall number - 3
	push eax	; some dword
	int 0x80
	add esp, 16
  %else
	push ebx ; save EBX
	mov eax, 3
	mov ecx, ebx 
	mov ebx, 0
	mov edx, 1
	int 0x80
	pop ebx	; restore EBX
  %endif

	test eax, eax	; if read zero bytes (end of file)
	jnz %%not_eof
	mov eax, -1
	jmp short %%done
%%not_eof:
	xor eax, eax	
	mov al, byte [ebx]	; save read character to eax
%%done:
	add esp, 4

	pop ebx
	popf
%endmacro

%define RES_BUFFER_SIZE 100
%define OPERATORS_STACK_SIZE 40
%define NUMBERS_STACK_SIZE 30 * 4

%define BASE 10
%define SPACE 32
%define CARRIAGE_RETURN 10
%define EOF -1	; end of file

%define	local1 ebp-4
%define	local2 ebp-8
%define	local3 ebp-12
%define	local4 ebp-18
%define arg1 ebp+8
%define arg2 ebp+12
%define arg3 ebp+16

%macro pcall 1-*
  %rep %0 - 1
    %rotate -1
	push dword %1
  %endrep
  %rotate -1
	call %1
	add esp, (%0 - 1) * 4
%endmacro


global _start

section .text

; is_digit(character: dword)
is_digit:
	push ebp
	mov ebp, esp
	
	cmp byte [arg1], '0'	; compare character with 0
	jl .false	; if less than '0', then false
	cmp byte [arg1], '9'
	jg .false	; if greater than '9', then false
	jmp short .true	; otherwise true

.false:	xor eax, eax
	jmp short .quit

.true:	mov eax, 1

.quit:	mov esp, ebp
	pop ebp
	ret

; is_operator(operator: dword)
is_operator:
	push ebp
	mov ebp, esp
	
	cmp byte [arg1], '+'
	je .true
	cmp byte [arg1], '-'
	je .true
	cmp byte [arg1], '*'
	je .true
	cmp byte [arg1], '/'
	je .true
	cmp byte [arg1], '%'
	je .true
	cmp byte [arg1], '^'
	je .true
	cmp byte [arg1], '('
	je .true
	cmp byte [arg1], ')'
	je .true

	jmp short .false	; otherwise false

.false:	xor eax, eax
	jmp short .quit

.true:	mov eax, 1

.quit:	mov esp, ebp
	pop ebp
	ret
	

; read_num(input: address)
; number in EAX
; number length in EDX
read_num:
	push ebp
	mov ebp, esp
	sub esp, 12	; local1 ([ebp-4]) - readed number
			; byte local2 ([ebp-8]) - number sign
			; byte (local2+1) - temp character 
	push ecx	; save ECX
	xor ecx, ecx	; number length := 0
	push ebx	; save EBX register value
	mov ebx, BASE	; put BASE value at EBX
	push esi	; save ESI register
	mov esi, [arg1]	; move first character address to ESI

	mov dword [local1], 0	; number := 0
	mov byte [local2], '+'	; sign := '+'

	; read number sign
	mov al, byte [esi]
	inc esi	; next character
	cmp al, '-'	; check that minus was read
	jne .not_minus
	mov [local2], al	; save sign
	jmp short .read_digit
.not_minus:
	cmp al, '+'	; check that pluse was read
	jne .skip_read	; if not, then digit was read

.read_digit:
	mov al, byte [esi]	; read character
	inc esi	; next character
.skip_read:
	cmp al, SPACE	; check that space was read
	je .end_read	; if space then end reading number

	cmp al, EOF	; check if the end of file has come
	je .end_read	; if EOF, then stop reading 

	push eax	; save character to stack
	pcall is_digit, eax	; check if read character is digit
	test eax, eax	; result in EAX (0 - false, 1 - true)
	pop eax		; restore character
	jz .end_read	; if EAX is 0, then stop read

	sub al, '0'	; char to digit		
	mov byte [local2 + 1], al	; save temp digit 
	mov eax, [local1]	; prepare 'eax' for multiplication
	mul ebx	; [eax] * 10
	xor edx, edx
	mov dl, byte [local2 + 1]	; move saved digit to EDX
	add eax, edx	; [eax] + readed digit
	mov [local1], eax
	inc ecx	; increment number length
	jmp short .read_digit

.end_read:	
	cmp byte [local2], '-'	; check a sign
	jne .quit	; if not negative then quit
	neg dword [local1]

.quit:	mov eax, [local1]	; return read number
	mov edx, ecx	; return number length

	pop esi	; restore ESI
	pop ebx	; restore EBX
	pop ecx

	mov esp, ebp
	pop ebp
	ret

; print_num(number: dword)
print_num:
	push ebp
	mov ebp, esp

	push ecx	; save ECX value to stack
	push ebx	; save EBX value
	mov ebx, BASE	; put base value in EBX

	mov eax, [arg1]	; move number to EAX
	mov edx, 1
	shl edx, 31	; [ebx] := 2^31
	test eax, edx	; check number sign
	jz .not_neg	; if (number & 2^32) = 1
	neg eax
	PUTCHAR '-'
.not_neg:
	xor ecx, ecx	; position for next char in current dword
	push dword 0	; push dword to stack
	mov byte [esp - 3 + ecx], 0	; push end of string character
	inc ecx	; get next byte position

.get_digit:
	xor edx, edx	; prepare a pare EDX:EAX for division
	div ebx	; divide by BASE, mod in EDX
	add dl, '0'	; digit to char 
	
	neg ecx	; -ecx
	mov byte [esp + 3 + ecx], dl	; save character to dword
					; byte number is (3 - ecx)
					; last byte is (esp + 3)
	neg ecx ; -(-ecx) = ecx
	inc ecx		; next byte position in dword	
	and ecx, 11b	; ecx mod 4 (ecx & 000...011)
			; because we have 4 bytes in dword
	test ecx, ecx	; if counter is 0, prepare next 4 bytes on stack
	jnz .fill_curr_dword	; fill next byte in current double word
	push dword 0	; else push next dword on stack
.fill_curr_dword:
	test eax, eax	; if remaining number is not zero
	jne .get_digit	; print next digit

	test ecx, ecx	; if ecx is not 0
	jnz .get_last_byte	; get last byte in current double word
	add esp, 4	; else if ecx is 0 then remove empty dword from stack
.get_last_byte:
	dec ecx	; get last byte position
	and ecx, 11b	; (-1) mod 4 = 3
.print_digit:
	neg ecx	; -ecx
	mov al, [esp + 3 + ecx]	; get next character
	neg ecx	; -(-ecx) = ecx
	test ecx, ecx	; if temp byte number is not zero
	jnz .next_byte	; get next byte of dword 
	add esp, 4	; else if byte number is 0, remove dword from stack
.next_byte:
	dec ecx	; get previous byte number
	and ecx, 11b	; (-1) mod 4 = 3
			; because we have 4 bytes in dword
	cmp al, 0	; if end of string
	je .print_end	; stop printing
	PUTCHAR al
	jmp short .print_digit
	
.print_end:
	pop ebx	; restore EBX
	pop ecx ; restore ECX

	mov esp, ebp
	pop ebp
	ret

; bin_pow(power: dword)
; second param (number) in EBX
bin_pow:
	push ebp
	mov ebp, esp

	cmp dword [arg1], 0
	jne .goon
	mov eax, 1	; a^0 = 1
	jmp short .quit

.goon:
	mov eax, [arg1]
	test eax, 1	; checks if n is even 
	jz .even_power	; if even then bin_pow(n / 2) * bin_pow(n / 2)

	dec eax
	pcall bin_pow, eax	; else bin_pow(n - 1) * a
				; result bin_pow(n-1) in EAX
	mul ebx	; bin_pow(n-1) * a ; a^(n-1) * a = a^n
	jmp short .quit
.even_power:
	shr eax, 1	; divide power by 2
	pcall bin_pow, eax	; result bin_pow(n/2) in EAX
	mul eax	; bin_pow(n/2) * bin_pow(n/2) ; a^(n/2) * a^(n/2) = a^n
.quit:
	mov esp, ebp
	pop ebp
	ret


; calc(a: dword; b: dword; operation: byte)
; calculation status in DL (0 - good, 1 - error)
calc:	push ebp
	mov ebp, esp

	mov eax, [arg1]	; prepare first operand

	cmp byte [arg3], '+'
	je .add
	cmp byte [arg3], '-'
	je .sub
	cmp byte [arg3], '*'
	je .mul
	cmp byte [arg3], '^'
	je .pow
	cmp byte [arg3], '/'
	je .div
	cmp byte [arg3], '%'
	je .div
	PRINT "*****Error: operation does not specified: "
	PUTCHAR byte [arg3]
	PUTCHAR 10
	mov dl, 1
	jmp .quit

.div:	xor edx, edx	; put 0 in EDX
	push ebx	; save EBX to stack
	mov ebx, [arg2]
	test ebx, ebx	; check if the divisor is 0
	jnz .not_zero
	PRINT "*****Error: division by zero"
	PUTCHAR 10
	mov dl, 1
	jmp .quit

.not_zero:
	cdq	; copy sign bit to each bit in EDX (for signed division)
	idiv ebx	; quotient of division is in EAX, remainder is EDX
	cmp byte [arg3], '%'	; if operation is remainder of division
	jne .div_end
	mov eax, edx	; return remainder of division
.div_end:
	pop ebx ; restore EBX
	jmp .end_calc

.add:	add eax, [arg2]
	jmp .end_calc

.sub:	sub eax, [arg2]
	jmp .end_calc

.mul:	imul eax, [arg2]
	jmp .end_calc

.pow:	cmp dword [arg2], 0
	jnl .goon_pow	; if power is not less than 0, then go on
	PRINT "*****Error: negative power"
	PUTCHAR 10
	mov dl, 1
	jmp short .quit
.goon_pow:
	push ebx	; save EBX value to stack
	mov ebx, eax	; prepare first operand (base)
	pcall bin_pow, [arg2]	; push second operand (power)
	pop ebx	; restore EBX

.end_calc:
	mov dl, 0	; return good calculation status
.quit:	mov esp, ebp
	pop ebp
	ret

; readln(string: address)
; AL set to 1 if there was an end of file situation
readln:	push ebp
	mov ebp, esp
	sub esp, 4	; eof flag

	push edi	; save edi value
	mov edi, [arg1] ; put address to the first character

	mov byte [local1], 0	; set quit flag to 0

.read:	GETCHAR
	cmp al, EOF	; check end of file
	jne .not_eof
	mov byte [local1], 1	; set EOF flag to 1
	jmp short .quit
.not_eof:
	cmp al, CARRIAGE_RETURN	; check carriage return
	je .quit
	mov byte [edi], al
	inc edi	; next character address
	jmp short .read	; read next char

.quit:	mov byte [edi], 0	; put end of string character	
	mov eax, [local1]	; save EOF flag
	pop edi	; restore EDI
	mov esp, ebp
	pop ebp
	ret
	
; println(string: address)
println:
	push ebp
	mov ebp, esp

	push esi	; save esi value
	mov esi, [arg1]	; put address to the first character

.print:	mov al, byte [esi]	
	cmp al, 0	; check end of string
	je .quit
	PUTCHAR al
	inc esi	; next character address
	jmp short .print	; read next char

.quit:	PUTCHAR 10
	
	pop esi
	mov esp, ebp
	pop ebp
	ret


; get_priority(operator: dword): byte
; result in AL 
get_priority:
	push ebp
	mov ebp, esp

	mov dl, byte [arg1]
	cmp dl, '('
	jne .close
	mov al, 0 
	jmp short .quit
.close: cmp dl, ')'
	jne .pluse
	mov al, -1
	jmp short .quit
.pluse:	cmp dl, '+'
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


; calc_expr(string: address): dword 
; return status in DL (0 - good, 1 - error)
calc_expr:
	push ebp
	mov ebp, esp

	sub esp, OPERATORS_STACK_SIZE + NUMBERS_STACK_SIZE + 4 * 4
		; reserve memory for two stacks
	mov eax, ebp
	sub eax, 16	; skip local1, local2, local3, local4
	mov [local1], eax	
		; address to last added elem on numbers stack
	mov eax, ebp
	sub eax, 16	; skip local1, local2, local3, local4
	sub eax, NUMBERS_STACK_SIZE	; skip memory for numbers stack
	mov [local2], eax	
		; address to last element on operators stack 
		; local1 - address to last element on numbers stack
		; local2 - address to last element on operators stack
		; local3, local4
	mov dword [local3], 0
	mov dword [local4], 0

	; push two 0 in numbers stack, the result if stack is empty
  %rep 2
	sub dword [local1], 4
	mov eax, [local1]
	mov dword [eax], 0
  %endrep

	; push final element in operators stack
	dec dword [local2]	; increase stack size 
	mov eax, [local2]
	mov byte [eax], '#'	; push final character

	push esi	; save ESI value
	mov esi, [arg1]
	push edi	; save EDI value
	mov edi, esp
	
	push ebx	; save EBX

.parse:	mov al, byte [esi]
	inc esi	; next string character
	cmp al, 0	; end of string
	je .pop_operators
	cmp al, SPACE	; ingore space character
	je .parse	; parse next character	
	
	; read varaible
	cmp al, '$'
	jne .not_var
	mov byte [local3 + 2], 1	; set varaible flag to 1
	jmp short .parse	; parse varaible number

.not_var:
	push eax	; save character on stack
	pcall is_digit, eax	; is character digit
	test eax, eax	; if eax = 0 then not digit
	pop eax
	jz .not_digit


	; read number
	dec esi	; put back read character
	pcall read_num, esi	; pass character address in params
	add esi, edx	; shift address by the length of read number

	; varaible number case 
	test byte [local3 + 2], 1	; check varaible flag
	jz .push_num	; it is not varaible
	mov ebx, [arg2]
	cmp eax, [ebx]	; if varaible number is valid 	
	jle .var_num
	; PRINT error
	PRINT "*****Error: invalid varaible number: "
	; print varaible number
	pcall print_num, eax
	PUTCHAR 10
	mov dl, 1	; status = 1 (error)
	jmp .quit
.var_num:
	mov edx, eax
	mov eax, [ebx + 4*edx]	; get varaible value
	and byte [local3 + 2], 0	; set varaible flag to 0
.push_num:
	; push number to numbers stack
	sub dword [local1], 4	; increase stack
	mov ebx, [local1]	; mov stack address to EBX
	mov [ebx], eax	; push element to stack

	mov byte [local3], 0	; set flag: last item was not operator

	jmp .parse
.not_digit:
	push eax
	pcall is_operator, eax
	pop ebx	; restore EAX (operator character) to EBX
	test eax, eax
	jz .not_operator

	; get new operator priority
	push eax
	pcall get_priority, ebx	; operator priority in AL
	mov dl, al	; save operator priority
	pop eax	; restore EAX

	; unary minus case
	cmp bl, '-'
	jne .not_unary_minus
	cmp byte [local3], 1	; check flag that last char was operator
	jne .not_unary_minus	
	or byte [local3+1], 1	; set unary operator flag to 1
	jmp short .push_operator	; push unary minus like binary operator	
.not_unary_minus:
	; open braket case
	cmp bl, '('
	je .push_operator	; just push open braket to stack

	; push operator to stack
.pop_operator:
	push edx
	mov edx, [local2]
	mov al, byte [edx]	; get last operator from stack
	pop edx
	cmp al, '#'	; check if stack is empty 
	je .push_operator	; if empty, then push new operator
				; else get operator from stack	
	cmp bl, ')'
	jne .not_braket
	cmp al, '('
	jne .not_braket
	inc byte [local2]	; pop braket from stack
	jmp .parse	; remove '(' by ')' and read next 
.not_braket:
	; get stack operator priority
	push edx	; save EDX
	push eax	; save EAX
	pcall get_priority, eax
	mov bh, al	; save stack operator priority
	pop eax	; restore EAX
	pop edx
	mov dh, bh

	cmp dl, dh	; compare operators priority
	jg .push_operator	; if new operator priority greater
				; then push new operator to stack
	inc byte [local2]	; else pop operator from stack
	; calculate
	push edx	; save EDX value
	push eax	; pass operator
	mov edx, [local1]	; push numbers stack address to EAX
	push dword [edx]	; pass first operand from stack
	add dword [local1], 4	; shift stack address 
	mov edx, [local1]
	push dword [edx]	; pass second operand
	call calc	; result in EAX
	add esp, 12	; clean stack frame
	test dl, dl	; check calculation status
	jnz .quit	; if status is 1, then quit 
	mov edx, [local1]	; get last numbers stack position
	mov [edx], eax	; save result of calculations on the stack
	pop edx	; restore EDX value

	jmp short .pop_operator	; get next operator from stack

.push_operator:
	dec dword [local2]
	mov eax, [local2]
	mov byte [eax], bl	; push new operator to stack 

	; open braket case
	cmp bl, '('	; if current operator is open braket, just push it
	je .next_char

	; case unary minus
	test byte [local3 + 1], 1	; check unary minus flag
	
	jz .next_char	; if flag = 0, go on
	; we have unary operator, push 0 to numbers stack
		; to make it binary operator: -x = 0 - x
	sub dword [local1], 4	; increase stack
	mov ebx, [local1]	; mov stack address to EBX
	mov dword [ebx], 0	; push element to stack
	and byte [local3 + 1], 0	; set unary minus flag to 0
		
.next_char:	
	mov byte [local3], 1	; set flag: last item was operator
	jmp .parse	; continue parsing
	
.not_operator:
	PRINT "*****Error: parsing an unknown character: "
	PUTCHAR bl
	PUTCHAR 10
	mov dl, 1	; return error status
	jmp short .quit	

.pop_operators:
	mov edx, [local2]
	mov al, byte [edx]	; get operator from stack
	cmp al, '#'	; check if stack is not empty
	je .end_calc
	push eax	; pass operator from stack
	inc dword [local2]	; shift stack address
	mov edx, [local1]	; push numbers stack address to EAX
	push dword [edx]	; pass first operand from stack
	add dword [local1], 4	; shift stack address 
	mov edx, [local1]
	push dword [edx]	; pass second operand
	call calc	; result in EAX
	add esp, 12	; clean stack frame
	test dl, dl	; check calculation status
	jnz .quit	; if status is zero, then quit
	mov edx, [local1]	; get last numbers stack position
	mov [edx], eax	; save result of calculations on the stack
	jmp short .pop_operators
	
.end_calc:	
	mov edx, [local1]	
	mov eax, [edx]	; return result
	mov dl, 0	; return good work status

.quit:	pop ebx
	pop edi
	pop esi

	mov esp, ebp
	pop ebp
	ret

help_cmd:
	push ebp
	mov ebp, esp
	PRINT "=== Commands ==="
	PUTCHAR 10
	PRINT "h - help"
	PUTCHAR 10
	PRINT "q - quit"
	PUTCHAR 10
	PRINT "c - clear buffer"
	PUTCHAR 10
	PRINT "================"
	PUTCHAR 10
	mov esp, ebp
	pop ebp
	ret


section .bss
numbers	resd 80
operations resb 80
string resb 80
buff resd RES_BUFFER_SIZE

section .text
_start: mov dword [buff], 0 ; set buffer size to 0	
.read:
	pcall readln, string
	test al, al	; check quit flag 
	jnz .quit	; if flag is 1, then quit 

%ifdef DEBUG_print
	pcall println, string
%endif
	; help command
	cmp byte [string], 'h'
	jne .quit_cmd 
	call help_cmd
	jmp short .read

.quit_cmd:
	; quit command
	cmp byte [string], 'q'
	jne .clear_cmd
	jmp .quit

.clear_cmd:
	; clear buffer command
	cmp byte [string], 'c'
	jne .expr 
	and dword [buff], 0
	jmp short .read

.expr:	; calculate expression
	pcall calc_expr, string, buff

	test dl, dl	; check calculation satus
	jnz .read	; if status is 1 (error), then read expression
			; again
	mov ecx, [buff]	; move buffer size to ecx
	inc ecx
	mov [buff + 4*ecx], eax	; save result to buffer
	mov [buff], ecx	; increase buffer size

	PRINT "$"
	; print result number in buffer 
	pcall print_num, ecx
	PRINT " = "

	; print result
	pcall print_num, [buff + 4*ecx] 
	PUTCHAR 10

	jmp .read

.quit:	; _exit syscall
%ifdef OS_FREEBSD
	push dword 0	; return status code - 0
	mov eax, 1	; _exit syscall number - 1
	push eax	; some dword
	int 0x80	; syscall
%elifdef OS_LINUX
	mov eax, 1
	mov ebx, 0
	int 0x80
%else
  %error Please choose OS_FREEBSD or OS_LINUX
%endif
