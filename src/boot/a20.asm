; See https://wiki.osdev.org/A20_Line

[BITS 64]


enableA20:
  call isA20On?
  jnc .end

  call enableA20BIOS
  call isA20On?
  jnc .end

  call enableA20Keyboard
  nop
  nop
  call isA20On?
  jnc .end

  call enableA20Fast
  nop
  nop
  nop
  nop
  call isA20On?

.end: ; with carry flag set or clear
  ret


; Check A20 line
; Returns to caller if A20 gate is cleared.
; Continues to A20_on if A20 line is set.
; Written by Elad Ashkcenazi

isA20On?:
  push rdi
  push rsi

  mov edi, 0x112345 ; odd megabyte address.
  mov esi, 0x012345 ; even megabyte address.
  mov [esi], esi    ; making sure that both addresses contain diffrent values.
  mov [edi], edi    ; (if A20 line is cleared the two pointers would point to the address 0x012345 that would contain 0x112345 (edi))
  cmpsd             ; compare addresses to see if the're equivalent.
  jne .A20_on       ; if not equivalent , A20 line is set.
  jmp .end          ; if equivalent , the A20 line is cleared.

.A20_on:
  clc
  jmp .end

.end:
  pop rsi
  pop rdi
  ret


enableA20Keyboard:
  push rax

  cli

  call    .a20wait
  mov     al, 0xAD
  out     0x64, al

  call    .a20wait
  mov     al, 0xD0
  out     0x64, al

  call    .a20wait2
  in      al, 0x60
  push    rax

  call    .a20wait
  mov     al, 0xD1
  out     0x64, al

  call    .a20wait
  pop     rax
  or      al, 2
  out     0x60, al

  call    .a20wait
  mov     al, 0xAE
  out     0x64, al

  call    .a20wait

  sti

  pop rax
  ret

.a20wait:
  in      al, 0x64
  test    al, 2
  jnz     .a20wait
  ret

.a20wait2:
  in      al, 0x64
  test    al, 1
  jz      .a20wait2
  ret


enableA20Fast:
  push ax
  in al, 0x92
  test al, 2
  jnz .after
  or al, 2
  and al, 0xFE
  out 0x92, al
.after:
  pop ax
  ret


enableA20BIOS:
  push ax
  mov     ax,2403h  ;--- A20-Gate Support ---
  int     15h
  jb      .after    ;INT 15h is not supported
  cmp     ah,0
  jnz     .after    ;INT 15h is not supported

  mov     ax,2402h  ;--- A20-Gate Status ---
  int     15h
  jb      .after    ;couldn't get status
  cmp     ah,0
  jnz     .after    ;couldn't get status

  cmp     al,1
  jz      .after    ;A20 is already activated

  mov     ax,2401h  ;--- A20-Gate Activate ---
  int     15h
  jb      .after    ;couldn't activate the gate
  cmp     ah,0
  jnz     .after    ;couldn't activate the gate

.after:
  pop ax
  ret
