%define stdin	0
%define stdout	1
%define stderr	2

%define sys_exit	1
%define sys_read	3
%define sys_write	4
%define	sys_open	5
%define sys_close	6

; open syscall
%define O_RDONLY	000h	; read only
%define O_WRONLY	001h	; write only
%define O_RDWR		002h	; read and write
%ifdef OS_FREEBSD
%define O_CREAT		200h	; allow file creation
%define O_EXCL		800h	; require file creation
%define O_TRUNC		400h	; erase file if it exists
%define O_APPEND	008h	; append in the end it file exists
%else	; assume it's Linux
%define O_CREAT		040h	; allow file creation
%define O_EXCL		080h	; require file creation
%define O_TRUNC		200h	; erase file if it exists
%define O_APPEND	400h	; append in the end it file exists
%endif

; if was an error, then EAX contains -1 and error code is in ECX
; else EAX contains syscall result and ECX contains 0
%macro kernel 1-* 
%ifdef OS_FREEBSD
  %rep %0
    %rotate -1
		push dword %1
  %endrep
		mov eax, [esp]	; get syscall number
		int 80h
		jnc %%ok
		mov ecx, eax	; error code in ecx
		mov eax, -1
		jmp short %%q
%%ok:		xor ecx, ecx
%%q:		add esp, %0 * 4
%elifdef OS_LINUX
  %if %0 > 1
		push ebx
    %if %0 > 4
		push esi
		push edi
		push ebp
    %endif
  %endif
  %rep %0
    %rotate -1
		push dword %1
  %endrep
		pop eax
  %if %0 > 1
		pop ebx
    %if %0 > 2
		pop ecx
      %if %0 > 3
		pop edx
        %if %0 > 4
		pop esi
	  %if %0 > 5
		pop edi
	    %if %0 > 6
		pop esi
	      %if %0 > 7
		%error "Cant't do syscall with 7+ params"
	      %endif
	    %endif
	  %endif
	%endif
      %endif
    %endif
  %endif
		int 80h
		mov ebx, eax
		and ebx, 0fffff000h	; check error
		cmp ebx, 0fffff000h
		jne %%ok
		mov ecx, eax	; error code in ecx
		neg ecx
		mov eax, -1
		jmp short %%q
%%ok:		xor ecx, ecx
%%q:		
  %if %0 > 1
    %if %0 > 4
	pop ebp
	pop edi
	pop esi
    %endif
	pop ebx
  %endif
%else
  %error Please define either OS_FREEBSD or OS_LINUX
%endif
%endmacro
