all:
	# No target specified #

SHELL := /bin/bash

ASM := nasm -w+all -f bin

STAGE1_SRCS := src/boot/stage1.asm src/boot/print.asm src/boot/defines.asm
STAGE2_SRCS := # src/boot/stage2.asm src/boot/print.asm src/boot/defines.asm

.ONESHELL:


build: out/floppy.bin

run:
	$(MAKE) -C qemu run

clean:
	$(RM) -r out/

.PHONY: all build run clean


out/:
	mkdir out

out/floppy.bin: $(STAGE1_SRCS) $(STAGE2_SRCS)  out/ out/stage1.bin # out/stage2.bin
	cat out/stage1.bin > out/floppy.bin
# cat out/stage2.bin >> out/floppy.bin

out/stage1.bin: $(STAGE1_SRCS)  out/ out/stage2.bin
	$(ASM) $(ASM_DEPFLAGS) src/boot/stage1.asm -o out/stage1.bin # -DSTAGE2_SECTORS=$$(( `stat -c "%s" out/stage2.bin` / 512 ))
# stage1 is already aligned and occupy exactly one sector
# out/stage2.bin: $(STAGE2_SRCS)  out/
# 	$(ASM) $(ASM_DEPFLAGS) src/boot/stage2.asm -o out/stage2.bin
# # stage2 is already aligned to sector size
# # Align stage2 to sector size (512 bytes)
# # sectors=$$(( (`stat -c "%s" out/.stage2.bin` + 511) / 512 ))
# # dd if=out/.stage2.bin ibs=512 count=$$sectors of=out/stage2.bin conv=sync
# # $(RM) out/.stage2.bin
