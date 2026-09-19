	.text
	.file	"lane_probe.d"
	.section	.text.sum_strict,"ax",@progbits
	.globl	sum_strict
	.p2align	4, 0x90
	.type	sum_strict,@function
sum_strict:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.LBB0_1
	movl	%esi, %eax
	andl	$7, %eax
	cmpq	$8, %rsi
	jae	.LBB0_4
	vxorps	%xmm0, %xmm0, %xmm0
	xorl	%ecx, %ecx
	jmp	.LBB0_6
.LBB0_1:
	vxorps	%xmm0, %xmm0, %xmm0
	retq
.LBB0_4:
	andq	$-8, %rsi
	vxorps	%xmm0, %xmm0, %xmm0
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB0_5:
	vmovss	(%rdi,%rcx,4), %xmm1
	vmovss	4(%rdi,%rcx,4), %xmm2
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vcvtss2sd	%xmm2, %xmm2, %xmm1
	vmovss	8(%rdi,%rcx,4), %xmm2
	vcvtss2sd	%xmm2, %xmm2, %xmm2
	vaddsd	%xmm1, %xmm0, %xmm0
	vaddsd	%xmm2, %xmm0, %xmm0
	vmovss	12(%rdi,%rcx,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vmovss	16(%rdi,%rcx,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vmovss	20(%rdi,%rcx,4), %xmm2
	vcvtss2sd	%xmm2, %xmm2, %xmm2
	vaddsd	%xmm1, %xmm0, %xmm0
	vaddsd	%xmm2, %xmm0, %xmm0
	vmovss	24(%rdi,%rcx,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	vmovss	28(%rdi,%rcx,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	addq	$8, %rcx
	cmpq	%rcx, %rsi
	jne	.LBB0_5
.LBB0_6:
	testq	%rax, %rax
	je	.LBB0_9
	leaq	(%rdi,%rcx,4), %rcx
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB0_8:
	vmovss	(%rcx,%rdx,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	incq	%rdx
	cmpq	%rdx, %rax
	jne	.LBB0_8
.LBB0_9:
	retq
.Lfunc_end0:
	.size	sum_strict, .Lfunc_end0-sum_strict
	.cfi_endproc

	.section	.text.sum_fixed_lane4,"ax",@progbits
	.globl	sum_fixed_lane4
	.p2align	4, 0x90
	.type	sum_fixed_lane4,@function
sum_fixed_lane4:
	.cfi_startproc
	cmpq	$4, %rsi
	jb	.LBB1_1
	leaq	-4(%rsi), %rcx
	cmpq	$4, %rcx
	jae	.LBB1_4
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	vxorpd	%xmm1, %xmm1, %xmm1
	jmp	.LBB1_6
.LBB1_1:
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	movq	%rax, %rcx
	subq	%rsi, %rcx
	jb	.LBB1_10
	jmp	.LBB1_14
.LBB1_4:
	movq	%rcx, %rdx
	shrq	$2, %rdx
	incq	%rdx
	andq	$-2, %rdx
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	vxorpd	%xmm1, %xmm1, %xmm1
	.p2align	4, 0x90
.LBB1_5:
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
	jne	.LBB1_5
.LBB1_6:
	testb	$4, %cl
	jne	.LBB1_8
	vmovss	(%rdi,%rax,4), %xmm2
	vmovss	4(%rdi,%rax,4), %xmm3
	vinsertps	$16, 8(%rdi,%rax,4), %xmm2, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vaddpd	%xmm2, %xmm0, %xmm0
	vinsertps	$16, 12(%rdi,%rax,4), %xmm3, %xmm2
	vcvtps2pd	%xmm2, %xmm2
	vaddpd	%xmm2, %xmm1, %xmm1
	addq	$4, %rax
.LBB1_8:
	vaddpd	%xmm1, %xmm0, %xmm0
	vshufpd	$1, %xmm0, %xmm0, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	movq	%rax, %rcx
	subq	%rsi, %rcx
	jae	.LBB1_14
.LBB1_10:
	movl	%esi, %edx
	subl	%eax, %edx
	andl	$7, %edx
	je	.LBB1_12
	.p2align	4, 0x90
.LBB1_11:
	vmovss	(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	incq	%rax
	decq	%rdx
	jne	.LBB1_11
.LBB1_12:
	cmpq	$-8, %rcx
	ja	.LBB1_14
	.p2align	4, 0x90
.LBB1_13:
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
	jne	.LBB1_13
.LBB1_14:
	retq
.Lfunc_end1:
	.size	sum_fixed_lane4, .Lfunc_end1-sum_fixed_lane4
	.cfi_endproc

	.section	.text.sum_fast,"ax",@progbits
	.globl	sum_fast
	.p2align	4, 0x90
	.type	sum_fast,@function
sum_fast:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.LBB2_1
	cmpq	$16, %rsi
	jae	.LBB2_4
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%eax, %eax
	jmp	.LBB2_7
.LBB2_1:
	vxorps	%xmm0, %xmm0, %xmm0
	retq
.LBB2_4:
	movq	%rsi, %rax
	andq	$-16, %rax
	vxorpd	%xmm0, %xmm0, %xmm0
	xorl	%ecx, %ecx
	vxorpd	%xmm1, %xmm1, %xmm1
	vxorpd	%xmm2, %xmm2, %xmm2
	vxorpd	%xmm3, %xmm3, %xmm3
	.p2align	4, 0x90
.LBB2_5:
	vcvtps2pd	(%rdi,%rcx,4), %ymm4
	vaddpd	%ymm4, %ymm0, %ymm0
	vcvtps2pd	16(%rdi,%rcx,4), %ymm4
	vaddpd	%ymm4, %ymm1, %ymm1
	vcvtps2pd	32(%rdi,%rcx,4), %ymm4
	vaddpd	%ymm4, %ymm2, %ymm2
	vcvtps2pd	48(%rdi,%rcx,4), %ymm4
	vaddpd	%ymm4, %ymm3, %ymm3
	addq	$16, %rcx
	cmpq	%rcx, %rax
	jne	.LBB2_5
	vaddpd	%ymm0, %ymm1, %ymm0
	vaddpd	%ymm0, %ymm2, %ymm0
	vaddpd	%ymm0, %ymm3, %ymm0
	vextractf128	$1, %ymm0, %xmm1
	vaddpd	%xmm1, %xmm0, %xmm0
	vshufpd	$1, %xmm0, %xmm0, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	cmpq	%rsi, %rax
	je	.LBB2_8
	.p2align	4, 0x90
.LBB2_7:
	vmovss	(%rdi,%rax,4), %xmm1
	vcvtss2sd	%xmm1, %xmm1, %xmm1
	vaddsd	%xmm1, %xmm0, %xmm0
	incq	%rax
	cmpq	%rax, %rsi
	jne	.LBB2_7
.LBB2_8:
	vzeroupper
	retq
.Lfunc_end2:
	.size	sum_fast, .Lfunc_end2-sum_fast
	.cfi_endproc

	.type	_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ,@object
	.section	.data._D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ,"aw",@progbits
	.globl	_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ
	.p2align	4, 0x0
_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ:
	.long	2147483652
	.long	0
	.asciz	"imagery.raster.internal.fixed_lane_probe"
	.zero	3
	.size	_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ, 52

	.hidden	_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ
	.type	_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ,@object
	.section	__minfo,"awR",@progbits,unique,1
	.weak	_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ
	.p2align	3, 0x0
_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ:
	.quad	_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ
	.size	_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ, 8

	.ident	"ldc version 1.41.0"
	.section	".note.GNU-stack","",@progbits
