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
