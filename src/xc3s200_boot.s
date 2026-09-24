	.file	"xc3s200_boot.c"
	.option nopic
	.attribute arch, "rv32i2p1"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.section	.text.boot,"ax",@progbits
	.align	2
	.globl	_start
	.type	_start, @function
_start:
	addi	sp,sp,-16
	sw	ra,12(sp)
	sw	s0,8(sp)
	addi	s0,sp,16
 #APP
# 27 "xc3s200_boot.c" 1
	la sp,_stack_top
# 0 "" 2
# 28 "xc3s200_boot.c" 1
	j run
# 0 "" 2
 #NO_APP
	nop
	lw	ra,12(sp)
	lw	s0,8(sp)
	addi	sp,sp,16
	jr	ra
	.size	_start, .-_start
	.globl	pLED
	.section	.srodata,"a"
	.align	2
	.type	pLED, @object
	.size	pLED, 4
pLED:
	.word	1179648
	.globl	pSSG
	.align	2
	.type	pSSG, @object
	.size	pSSG, 4
pSSG:
	.word	1310720
	.globl	pUart
	.align	2
	.type	pUart, @object
	.size	pUart, 4
pUart:
	.word	1572864
	.text
	.align	2
	.globl	putNibble
	.type	putNibble, @function
putNibble:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	mv	a5,a0
	sb	a5,-17(s0)
	nop
.L3:
	li	a5,1572864
	lw	a5,0(a5)
	andi	a5,a5,1024
	beq	a5,zero,.L3
	lbu	a5,-17(s0)
	andi	a5,a5,15
	sb	a5,-17(s0)
	lbu	a4,-17(s0)
	li	a5,9
	bleu	a4,a5,.L4
	lbu	a5,-17(s0)
	addi	a5,a5,55
	mv	a4,a5
	j	.L5
.L4:
	lbu	a5,-17(s0)
	addi	a5,a5,48
	mv	a4,a5
.L5:
	li	a5,1572864
	sw	a4,0(a5)
	nop
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	putNibble, .-putNibble
	.align	2
	.globl	putChar
	.type	putChar, @function
putChar:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	sw	a0,-20(s0)
	j	.L7
.L9:
	nop
.L8:
	li	a5,1572864
	lw	a5,0(a5)
	andi	a5,a5,1024
	beq	a5,zero,.L8
	lw	a5,-20(s0)
	lbu	a4,0(a5)
	li	a5,1572864
	sw	a4,0(a5)
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L7:
	lw	a5,-20(s0)
	lbu	a5,0(a5)
	bne	a5,zero,.L9
	nop
	nop
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	putChar, .-putChar
	.globl	pSysReset
	.section	.srodata
	.align	2
	.type	pSysReset, @object
	.size	pSysReset, 4
pSysReset:
	.zero	4
	.globl	pBootMsg
	.section	.rodata
	.align	2
.LC0:
	.string	"\rBoot xc3c200, wait for xmodem system binary...\r"
	.section	.srodata
	.align	2
	.type	pBootMsg, @object
	.size	pBootMsg, 4
pBootMsg:
	.word	.LC0
	.text
	.align	2
	.globl	run
	.type	run, @function
run:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	li	a5,1310720
	li	a4,-2086428672
	addi	a4,a4,903
	sw	a4,0(a5)
	lui	a5,%hi(.LC0)
	addi	a5,a5,%lo(.LC0)
	mv	a0,a5
	call	putChar
	nop
.L11:
	li	a5,1572864
	lw	a5,0(a5)
	andi	a5,a5,1024
	beq	a5,zero,.L11
	nop
.L12:
	li	a5,1572864
	lw	a4,0(a5)
	li	a5,65536
	and	a5,a4,a5
	beq	a5,zero,.L12
	sw	zero,-20(s0)
.L14:
	li	a5,1572864
	lw	a5,0(a5)
	sw	a5,-24(s0)
	lw	a4,-24(s0)
	li	a5,65536
	addi	a5,a5,256
	and	a4,a4,a5
	li	a5,65536
	addi	a5,a5,256
	bne	a4,a5,.L13
	lw	a5,-24(s0)
	andi	a4,a5,0xff
	lw	a5,-20(s0)
	sb	a4,0(a5)
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L13:
	lw	a4,-24(s0)
	li	a5,65536
	and	a5,a4,a5
	bne	a5,zero,.L14
	li	a5,0
	jalr	a5
	nop
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	run, .-run
	.ident	"GCC: (xPack GNU RISC-V Embedded GCC x86_64) 15.2.0"
	.section	.note.GNU-stack,"",@progbits
