%define STAGE1_BP         0xFFFF

; < 0x1000
%define STAGE2_SEG        0x0900
%define STAGE2_FLAT_ADDR  STAGE2_SEG * 0x10
%define STAGE2_SS         0x1900
