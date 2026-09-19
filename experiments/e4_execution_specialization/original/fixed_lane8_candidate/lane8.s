	.text
	.file	"lane8.d"
	.section	.text.sumFixedLane4,"ax",@progbits
	.globl	sumFixedLane4
	.p2align	4, 0x90
	.type	sumFixedLane4,@function
sumFixedLane4:
	.cfi_startproc
	cmpq	$4, %rsi
	jb	.LBB0_1
	leaq	-4(%rsi), %rcx
	cmpq	$4, %rcx
	jae	.LBB0_4
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	vxorpd	%xmm1, %xmm1, %xmm1
	jmp	.LBB0_6
.LBB0_1:
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	movq	%rax, %rcx
	subq	%rsi, %rcx
	jb	.LBB0_10
	jmp	.LBB0_14
.LBB0_4:
	movq	%rcx, %rdx
	shrq	$2, %rdx
	incq	%rdx
	andq	$-2, %rdx
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	vxorpd	%xmm1, %xmm1, %xmm1
	.p2align	4, 0x90
.LBB0_5:
	vmovss	(%rdi,%rax,4), %xmm2
	vmovss	4(%rdi,%rax,4), %xmm3
	vmovss	16(%rdi,%rax,4), %xmm4
	vmovss	20(%rdi,%rax,4), %xmm5
	vinsertps	$16, 8(%rdi,%rax,4), %xmm2, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vaddpd	%xmm2, %xmm0, %xmm0
	vinsertps	$16, 12(%rdi,%rax,4), %xmm3, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vaddpd	%xmm2, %xmm1, %xmm1
	vinsertps	$16, 24(%rdi,%rax,4), %xmm4, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vinsertps	$16, 28(%rdi,%rax,4), %xmm5, %xmm3
	vaddpd	%xmm2, %xmm0, %xmm0
	vcvtps2pd	%xmm3, %xmm2
	vaddpd	%xmm2, %xmm1, %xmm1
	addq	$8, %rax
	addq	$-2, %rdx
	jne	.LBB0_5
.LBB0_6:
	testb	$4, %cl
	jne	.LBB0_8
	vmovss	(%rdi,%rax,4), %xmm2
	vmovss	4(%rdi,%rax,4), %xmm3
	vinsertps	$16, 8(%rdi,%rax,4), %xmm2, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vaddpd	%xmm2, %xmm0, %xmm0
	vinsertps	$16, 12(%rdi,%rax,4), %xmm3, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vaddpd	%xmm2, %xmm1, %xmm1
	addq	$4, %rax
.LBB0_8:
	vaddpd	%xmm1, %xmm0, %xmm0
	vshufpd	$1, %xmm0, %xmm0, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	movq	%rax, %rcx
	subq	%rsi, %rcx
	jae	.LBB0_14
.LBB0_10:
	movl	%esi, %edx
	subl	%eax, %edx
	andl	$7, %edx
	je	.LBB0_12
	.p2align	4, 0x90
.LBB0_11:
	vmovss	(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	incq	%rax
	decq	%rdx
	jne	.LBB0_11
.LBB0_12:
	cmpq	$-8, %rcx
	ja	.LBB0_14
	.p2align	4, 0x90
.LBB0_13:
	vmovss	(%rdi,%rax,4), %xmm1
	vmovss	4(%rdi,%rax,4), %xmm2
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vcvtss2sd	%xmm2, %xmm2, %xmm1
	vmovss	8(%rdi,%rax,4), %xmm2
	vcvtss2sd	%xmm2, %xmm2, %xmm2
	vaddsd	%xmm1, %xmm0, %xmm0
	vaddsd	%xmm2, %xmm0, %xmm0
	vmovss	12(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vmovss	16(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vmovss	20(%rdi,%rax,4), %xmm2
	vcvtss2sd	%xmm2, %xmm2, %xmm2
	vaddsd	%xmm1, %xmm0, %xmm0
	vaddsd	%xmm2, %xmm0, %xmm0
	vmovss	24(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vmovss	28(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	addq	$8, %rax
	cmpq	%rax, %rsi
	jne	.LBB0_13
.LBB0_14:
	retq
.Lfunc_end0:
	.size	sumFixedLane4, .Lfunc_end0-sumFixedLane4
	.cfi_endproc

	.section	.text.sumFixedLane8,"ax",@progbits
	.globl	sumFixedLane8
	.p2align	4, 0x90
	.type	sumFixedLane8,@function
sumFixedLane8:
	.cfi_startproc
	cmpq	$8, %rsi
	jb	.LBB1_1
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	movq	%rsi, %rcx
	vxorpd	%xmm1, %xmm1, %xmm1
	vxorpd	%xmm2, %xmm2, %xmm2
	vxorpd	%xmm3, %xmm3, %xmm3
	.p2align	4, 0x90
.LBB1_3:
	vmovss	16(%rdi,%rax,4), %xmm4
	vmovss	20(%rdi,%rax,4), %xmm5
	vmovss	24(%rdi,%rax,4), %xmm6
	vmovss	28(%rdi,%rax,4), %xmm7
	vinsertps	$16, (%rdi,%rax,4), %xmm4, %xmm4
	vcvtps2pd	%xmm4, %xmm4
	vaddpd	%xmm4, %xmm3, %xmm3
	vinsertps	$16, 4(%rdi,%rax,4), %xmm5, %xmm4
	vcvtps2pd	%xmm4, %xmm4
	vinsertps	$16, 8(%rdi,%rax,4), %xmm7, %xmm5
	vaddpd	%xmm4, %xmm2, %xmm2
	vcvtps2pd	%xmm5, %xmm4
	vaddpd	%xmm4, %xmm1, %xmm1
	vinsertps	$16, 12(%rdi,%rax,4), %xmm6, %xmm4
	vcvtps2pd	%xmm4, %xmm4
	vaddpd	%xmm4, %xmm0, %xmm0
	addq	$8, %rax
	addq	$-8, %rcx
	cmpq	$7, %rcx
	ja	.LBB1_3
	vaddpd	%xmm3, %xmm2, %xmm2
	vaddpd	%xmm1, %xmm0, %xmm0
	vaddpd	%xmm2, %xmm0, %xmm0
	vshufpd	$1, %xmm0, %xmm0, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	movq	%rax, %rcx
	subq	%rsi, %rcx
	jb	.LBB1_6
	jmp	.LBB1_10
.LBB1_1:
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	movq	%rax, %rcx
	subq	%rsi, %rcx
	jae	.LBB1_10
.LBB1_6:
	movl	%esi, %edx
	subl	%eax, %edx
	andl	$7, %edx
	je	.LBB1_8
	.p2align	4, 0x90
.LBB1_7:
	vmovss	(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	incq	%rax
	decq	%rdx
	jne	.LBB1_7
.LBB1_8:
	cmpq	$-8, %rcx
	ja	.LBB1_10
	.p2align	4, 0x90
.LBB1_9:
	vmovss	(%rdi,%rax,4), %xmm1
	vmovss	4(%rdi,%rax,4), %xmm2
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vcvtss2sd	%xmm2, %xmm2, %xmm1
	vmovss	8(%rdi,%rax,4), %xmm2
	vcvtss2sd	%xmm2, %xmm2, %xmm2
	vaddsd	%xmm1, %xmm0, %xmm0
	vaddsd	%xmm2, %xmm0, %xmm0
	vmovss	12(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vmovss	16(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vmovss	20(%rdi,%rax,4), %xmm2
	vcvtss2sd	%xmm2, %xmm2, %xmm2
	vaddsd	%xmm1, %xmm0, %xmm0
	vaddsd	%xmm2, %xmm0, %xmm0
	vmovss	24(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vmovss	28(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	addq	$8, %rax
	cmpq	%rax, %rsi
	jne	.LBB1_9
.LBB1_10:
	retq
.Lfunc_end1:
	.size	sumFixedLane8, .Lfunc_end1-sumFixedLane8
	.cfi_endproc

	.type	_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ,@object
	.section	.data._D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ,"aw",@progbits
	.globl	_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ
	.p2align	4, 0x0
_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ:
	.long	2147483652
	.long	0
	.asciz	"imagery.raster.internal.fixed_lane8_probe"
	.zero	2
	.size	_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ, 52

	.hidden	_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ
	.type	_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ,@object
	.section	__minfo,"awR",@progbits,unique,1
	.weak	_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ
	.p2align	3, 0x0
_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ:
	.quad	_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ
	.size	_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ, 8

	.ident	"ldc version 1.41.0"
	.section	".note.GNU-stack","",@progbits
