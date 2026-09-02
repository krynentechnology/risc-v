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
	.globl	pSSG
	.section	.srodata,"a"
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
	.globl	putChar
	.type	putChar, @function
putChar:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	sw	a0,-20(s0)
	j	.L3
.L5:
	nop
.L4:
	li	a5,1572864
	lw	a5,0(a5)
	andi	a5,a5,1024
	beq	a5,zero,.L4
	lw	a5,-20(s0)
	lbu	a4,0(a5)
	li	a5,1572864
	sw	a4,0(a5)
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L3:
	lw	a5,-20(s0)
	lbu	a5,0(a5)
	bne	a5,zero,.L5
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
.L7:
	li	a5,1572864
	lw	a5,0(a5)
	andi	a5,a5,1024
	beq	a5,zero,.L7
	nop
.L8:
	li	a5,1572864
	lw	a4,0(a5)
	li	a5,65536
	and	a5,a4,a5
	beq	a5,zero,.L8
	sw	zero,-20(s0)
.L10:
	li	a5,1572864
	lw	a5,0(a5)
	sw	a5,-24(s0)
	lw	a4,-24(s0)
	li	a5,65536
	addi	a5,a5,256
	and	a4,a4,a5
	li	a5,65536
	addi	a5,a5,256
	bne	a4,a5,.L9
	lw	a5,-24(s0)
	andi	a4,a5,0xff
	lw	a5,-20(s0)
	sb	a4,0(a5)
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L9:
	lw	a4,-24(s0)
	li	a5,65536
	and	a5,a4,a5
	bne	a5,zero,.L10
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
