%define PAGING_ADDR 0x9000

[ORG 0x7C00]
[BITS 16]

; ; Loads stage2 into memory and jumps there

; ; Compile with STAGE2_SECTORS macro predefined
; %ifndef STAGE2_SECTORS
;   %fatal "STAGE2_SECTORS not defined"
; %endif
; %ifndef ERROR_ATTEMPTS
;   %define ERROR_ATTEMPTS 3
; %endif


jmp word 0x0000:main ; Some BIOS' may load us at 0x0000:0x7C00 while other may load us at 0x07C0:0x0000


main:
  xor ax, ax
  mov ss, ax
  mov ds, ax
  mov es, ax
  cld

  ; Set up stack so that it starts below main.
  mov bp, main
  mov bp, sp

  ; mov si, Success
  ; call print

  call checkCPU ; Check whether we support Long Mode or not.
  jc .noLongMode

  ; clear
  mov di, PAGING_ADDR
  push di ; push PAGING_ADDR
  mov cx, 0x0400
  xor ax, ax
  rep stosd
  pop di  ; pop PAGING_ADDR

  ; Build 1st PML4E pointing to 1st PDPTE
  mov eax, PAGING_ADDR + 0x1000  |  1 << 0  |  1 << 1
  mov [es:di], eax

  ; Build 1st PDPTE mapping 1GB page
  mov eax, 1 << 0  |  1 << 1  |  1 << 7 ; Point it to 0x0000
  mov [es:di + 0x1000], eax

  ; Disable IRQs
  mov al, 0xFF  ; Out 0xFF to 0xA1 and 0x21 to disable all IRQs.
  out 0xA1, al
  out 0x21, al
  nop
  nop

  cli ; Disable interrupts

  ; Enter long mode.
  mov eax, cr4                ; Set the A-register to control register 4
  ; or eax, 1 << 5  |  1 << 7 ; Set PAE-bit and PGE-bit  [V3 2.5]
  or eax, 1 << 5              ; Set PAE-bit  [V3 2.5]
  mov cr4, eax                ; Set control register 4 to the A-register

  mov eax, PAGING_ADDR  ; Set the A-register to PML4T address
  mov cr3, eax          ; Set control register 3 to the A-register

  mov ecx, 0xC0000080 ; Set the C-register to 0xC0000080, which is the EFER MSR
  rdmsr               ; Read from the MSR
  or eax, 1 << 8      ; Set LME-bit
  wrmsr               ; Write to the MSR

  mov eax, cr0                ; Set the A-register to control register 0
  or eax, 1 << 31  |  1 << 0  ; Set PG-bit and PM-bit  [V3 2.5]
  mov cr0, eax                ; Set control register 0 to the A-register

  lgdt [GDT64.GDTR] ; Load GDT64 defined below

  jmp dword GDT64.Code:longMode ; Load CS with 64 bit segment and flush the instruction cache

[BITS 16]

.noLongMode:
  mov si, NoLongMode
  call print

.die:
  hlt
  jmp .die

NoLongMode: db "[ERROR] long mode not supported", 0x0A, 0x0D, 0


[BITS 64]
longMode:
  nop
  nop

  mov ax, GDT64.Data
  mov ss, ax
  mov ds, ax
  mov es, ax

  ; ; Set bp and sp
  ; call enableA20 ; Don't fir in one sector, relocate to kernel init
  ; jc .a20Error

  ; Blank out the screen to a black color.
  mov edi, 0xB8000
  mov rcx, 500                ; Since we are clearing uint64_t over here, we put the count as Count/4.
  mov rax, 0x0220022002200220 ; Set the value to set the screen to: Black background, green foreground, blank spaces.
  rep stosq                   ; Clear the entire screen.

  ; debug print
  lea edi, [0xB8000 + 80 * 2]
  mov dword [edi], 0x02420241
  mov dword [edi + 4], 0x02440243

  jmp $

.a20Error:
  ; TODO: Display full error message
  ; Display "A20!"
  lea edi, [0xB8000]

  mov rax, 0x0221023002320241
  mov qword [edi], rax

.die:
  hlt
  jmp .die

[BITS 16]

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
  dw GDT64.end - GDT64 - 1  ; 16-bit Limit
  dq GDT64                  ; 64-bit Address


; disk_read:
;   ; Load stage2 from floppy
;   ; See http://www.ctyme.com/intr/rb-0607.htm
;   mov ah, 2               ; ah <- int 0x13 function. 0x02 = 'read'
;   mov al, STAGE2_SECTORS  ; al <- number of sectors to read (0x01 .. 0x80)
;   mov cl, 2               ; cl <- sector (0x01 .. 0x11)
;                           ; 0x01 is our boot sector, 0x02 is the first 'available' sector
;   mov ch, 0               ; ch <- cylinder (0x0 .. 0x3FF, upper 2 bits in 'cl')
;                           ; dl <- drive number. Our caller sets it as a parameter and gets it from BIOS
;                           ; (0 = floppy, 1 = floppy2, 0x80 = hdd, 0x81 = hdd2)
;   mov dh, 0               ; dh <- head number (0x0 .. 0xF)
;   mov bx, STAGE2_SEG      ; [es:bx] <- pointer to buffer where the data will be stored
;   mov es, bx
;   xor bx, bx              ; Actual address is es * 0x10 + bx == 0x9000
;   int 0x13                ; BIOS interrupt
;   jc disk_read_error      ; if error (stored in the carry bit)
;
;   cmp al, STAGE2_SECTORS  ; BIOS also sets 'al' to the # of sectors read. Compare it.
;   jne disk_SectorsError
;
;   jmp STAGE2_SEG:0x0000  ; Jump to stage2
;
; disk_read_error:
;   mov si, DiskError
;   call print
;   mov dh, ah      ; ah = error code, dl = disk drive that dropped the error
;   call print_hex  ; Check out the code at http://www.ctyme.com/intr/rb-0606.htm#Table234
;   jmp disk_error
;
; disk_SectorsError:
;   mov si, SectorsError
;   call print
;   jmp disk_error
;
; disk_error:
;   mov dh, [ErrorCount]
;   cmp dh, ERROR_ATTEMPTS
;   jge disk_loop
;   inc dh
;   mov [ErrorCount], dh
;
;   jmp disk_read
;
; disk_loop:
;   mov si, FatalError
;   call print
;   jmp main.die
;
; DiskError:     db "[ERROR] Disk read error", 0x0A, 0x0D, 0
; SectorsError:  db "[ERROR] Incorrect number of sectors read", 0x0A, 0x0D, 0
; FatalError:    db "[ERROR] Couldn't read from disk, entering infinite loop", 0x0A, 0x0D, 0
; ErrorCount:    db 1


[BITS 16]
; Checks whether CPU supports long mode or not.

; Returns with carry set if CPU doesn't support long mode.

checkCPU:
  pushfd              ; Get flags in EAX register.

  pop eax
  mov ecx, eax
  xor eax, 0x200000
  push eax
  popfd

  pushfd
  pop eax
  xor eax, ecx
  shr eax, 21
  and eax, 1          ; Check whether bit 21 is set or not. If EAX now contains 0, CPUID isn't supported.
  push ecx
  popfd

  test eax, eax
  jz .noLongMode

  mov eax, 0x80000000
  cpuid

  cmp eax, 0x80000001 ; Check whether extended function 0x80000001 is available are not.
  jb .noLongMode      ; If not, long mode not supported.

  mov eax, 0x80000001
  cpuid
  test edx, 1 << 29   ; Test if the LM-bit, is set or not.
  jz .noLongMode      ; If not Long mode not supported.

  ret

.noLongMode:
  stc
  ret

%include "src/boot/print.asm"
; %include "src/boot/a20.asm"


; write bootsig
epilogue:
  %if ($ - $$) > 510
    %fatal "Bootloader stage1 sector exceeded 512 bytes!"
  %endif
  times 510 - ($ - $$) db 0xCC
  dw 0xAA55
