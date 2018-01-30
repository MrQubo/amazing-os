%include "src/boot/defines.asm"

%if STAGE2_FLAT_ADDR >= 0x10000
  %fatal "Longer segment addresses not supported."
%endif

[BITS 16]
SECTALIGN OFF
[ORG 0]

; Inits GDT and enters protected mode. Enters long mode. Loads kernel into memory and jumps there.


xor ax, ax
mov ss, ax
mov ds, ax
mov es, ax
; cs is already set

; Set up stack so that it starts below Main.
mov bp, Main
mov bp, sp

; mov bx, Success
; call print

cli ; Disable interrupts

mov eax, cr4              ; Set the A-register to control register 4
or eax, 1 << 5  |  1 << 7 ; Set PAE-bit and PGE-bit  [V3 2.5]
mov cr4, eax              ; Set control register 4 to the A-register

mov eax, (STAGE2_FLAT_ADDR + PML4T - $$)  ; Set the A-register to PML4T
mov cr3, eax                              ; Set control register 3 to the A-register


mov ecx, 0xC0000080 ; Set the C-register to 0xC0000080, which is the EFER MSR
rdmsr               ; Read from the MSR
or eax, 1 << 8      ; Set LM-bit
wrmsr               ; Write to the MSR

mov eax, cr0                ; Set the A-register to control register 0
or eax, 1 << 31  |  1 << 0  ; Set PG-bit and PM-bit  [V3 2.5]
mov cr0, eax                ; Set control register 0 to the A-register

lgdt [STAGE2_FLAT_ADDR + GDT64.GDTR]  ; Load the 64-bit global descriptor table.

jmp (STAGE2_FLAT_ADDR + GDT64.Code):(STAGE2_FLAT_ADDR + start64)  ; Set the code segment and enter 64-bit long mode.

; Success: db "Hello, World!", 0x0A, 0x0A, 0
;
; %include "src/boot/print.asm"

; [BITS 32]
; start32:
;   mov ax, (GDT32.Data - GDT32)
;   mov ds, ax
;   mov es, ax
;
;   ; debug print
;   lea eax, [0xB8000]
;   mov dword [eax], 0x02420241
;   mov dword [eax + 4], 0x02440243
;
;   jmp $

[BITS 64]
start64:
  mov ax, STAGE2_FLAT_ADDR + GDT64.Data
  mov ds, ax
  mov es, ax

  ; debug print
  lea eax, [0xB8000]
  mov dword [eax], 0x02420241
  mov dword [eax + 4], 0x02440243

  jmp $


; ; GDT 32-bit protected mode
; ; [V3 3.4.5]
; %define GDT32_CODE_SEGMENT_DESCRIPTOR 0xFFFF << 0  |  0b1010 << 40  |  1 << 44  |  1 << 47  |  0xFF << 48  |  1 << 54  |  1 << 55
; %define GDT32_DATA_SEGMENT_DESCRIPTOR 0xFFFF << 0  |  0b0010 << 40  |  1 << 44  |  1 << 47  |  0xFF << 48  |  1 << 54  |  1 << 55
; ALIGN 8, db 0xCC  ; Align GDT to 8 bytes. [V3 3.5.1]
; GDT32:
;   .Null: dq 0
;   .Code: dq GDT32_CODE_SEGMENT_DESCRIPTOR
;   .Data: dq GDT32_DATA_SEGMENT_DESCRIPTOR
;   .end:
;
; ALIGN 4, db 0xCC  ;
; dw 0              ; Align GDTR to odd word address. [V3 3.5.1]
; .GDTR:
;   dw GDT32.end - GDT32 - 1  ; 16-bit Limit
;   dq GDT32                  ; 64-bit Address


; GDT 64-bit long mode
; [V3 3.4.5]
%define GDT64_CODE_SEGMENT_DESCRIPTOR 0xFFFF << 0  |  0b1010 << 40  |  1 << 44  |  1 << 47  |  0xFF << 48  |  1 << 53  |  1 << 55
%define GDT64_DATA_SEGMENT_DESCRIPTOR 0xFFFF << 0  |  0b0010 << 40  |  1 << 44  |  1 << 47  |  0xFF << 48  |  1 << 54  |  1 << 55
ALIGN 8, db 0xCC  ; Align GDT to 8 bytes. [V3 3.5.1]
GDT64:
  .Null: equ $ - GDT64
    dq 0
  .Code: equ $ - GDT64
    dq GDT64_CODE_SEGMENT_DESCRIPTOR
  .Data: equ $ - GDT64
    dq GDT64_DATA_SEGMENT_DESCRIPTOR
  .end:

ALIGN 4, db 0xCC  ;
dw 0              ; Align GDTR to odd word address. [V3 3.5.1]
.GDTR:
  dw GDT64.end - GDT64 - 1    ; 16-bit Limit
  dq STAGE2_FLAT_ADDR + GDT64 ; 64-bit Address


; TODO: alignment
PML4T:
  dq 1 << 0  |  1 << 1  |  (STAGE2_FLAT_ADDR + PDPT - $$) << 12
  times 511 dq 0

; TODO: alignment
PDPT:
  dq 1 << 0  |  1 << 1  |  1 << 7
  times 511 dq 0


; align file
epilogue:
  %if ($ - $$) > 0xFFFF
    %fatal "Bootloader stage2 exceeded available space!"
  %endif
  times (-($ - $$)) % 512 db 0xCC
