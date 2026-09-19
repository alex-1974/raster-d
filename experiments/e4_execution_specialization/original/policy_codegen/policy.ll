; ModuleID = '/tmp/d-imagery-e4-policy-codegen-20260917-172244/policy_probe.d'
source_filename = "/tmp/d-imagery-e4-policy-codegen-20260917-172244/policy_probe.d"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%0 = type { i32, i32, [45 x i8] }

@_D7imagery6raster8internal20policy_codegen_probe12__ModuleInfoZ = global %0 { i32 -2147483644, i32 0, [45 x i8] c"imagery.raster.internal.policy_codegen_probe\00" } ; [#uses = 1]
@_D7imagery6raster8internal20policy_codegen_probe11__moduleRefZ = linkonce_odr hidden global ptr @_D7imagery6raster8internal20policy_codegen_probe12__ModuleInfoZ, section "__minfo" ; [#uses = 1]
@llvm.used = appending global [1 x ptr] [ptr @_D7imagery6raster8internal20policy_codegen_probe11__moduleRefZ], section "llvm.metadata" ; [#uses = 0]

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite) uwtable
define noundef zeroext i1 @copy_unknown_alias(ptr nocapture readonly %source_arg, ptr nocapture writeonly %target_arg, i64 %length_arg) local_unnamed_addr #0 {
  %.not = icmp eq i64 %length_arg, 0              ; [#uses = 1]
  br i1 %.not, label %endfor, label %iter.check

iter.check:                                       ; preds = %0
  %target_arg5 = ptrtoint ptr %target_arg to i64  ; [#uses = 1]
  %source_arg6 = ptrtoint ptr %source_arg to i64  ; [#uses = 1]
  %min.iters.check = icmp ult i64 %length_arg, 16 ; [#uses = 1]
  %1 = sub i64 %target_arg5, %source_arg6         ; [#uses = 1]
  %diff.check = icmp ult i64 %1, 128              ; [#uses = 1]
  %or.cond = select i1 %min.iters.check, i1 true, i1 %diff.check ; [#uses = 1]
  br i1 %or.cond, label %forbody.preheader, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check7 = icmp ult i64 %length_arg, 128 ; [#uses = 1]
  br i1 %min.iters.check7, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.vec = and i64 %length_arg, -128              ; [#uses = 4]
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ] ; [#uses = 3, type = i64]
  %2 = getelementptr inbounds i8, ptr %target_arg, i64 %index ; [#uses = 4, type = ptr]
  %3 = getelementptr inbounds i8, ptr %source_arg, i64 %index ; [#uses = 4, type = ptr]
  %4 = getelementptr inbounds i8, ptr %3, i64 32  ; [#uses = 1, type = ptr]
  %5 = getelementptr inbounds i8, ptr %3, i64 64  ; [#uses = 1, type = ptr]
  %6 = getelementptr inbounds i8, ptr %3, i64 96  ; [#uses = 1, type = ptr]
  %wide.load = load <32 x i8>, ptr %3, align 1    ; [#uses = 1]
  %wide.load8 = load <32 x i8>, ptr %4, align 1   ; [#uses = 1]
  %wide.load9 = load <32 x i8>, ptr %5, align 1   ; [#uses = 1]
  %wide.load10 = load <32 x i8>, ptr %6, align 1  ; [#uses = 1]
  %7 = getelementptr inbounds i8, ptr %2, i64 32  ; [#uses = 1, type = ptr]
  %8 = getelementptr inbounds i8, ptr %2, i64 64  ; [#uses = 1, type = ptr]
  %9 = getelementptr inbounds i8, ptr %2, i64 96  ; [#uses = 1, type = ptr]
  store <32 x i8> %wide.load, ptr %2, align 1
  store <32 x i8> %wide.load8, ptr %7, align 1
  store <32 x i8> %wide.load9, ptr %8, align 1
  store <32 x i8> %wide.load10, ptr %9, align 1
  %index.next = add nuw i64 %index, 128           ; [#uses = 2]
  %10 = icmp eq i64 %index.next, %n.vec           ; [#uses = 1]
  br i1 %10, label %middle.block, label %vector.body, !llvm.loop !1

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %length_arg        ; [#uses = 1]
  br i1 %cmp.n, label %endfor, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %n.vec.remaining = and i64 %length_arg, 112     ; [#uses = 1]
  %min.epilog.iters.check = icmp eq i64 %n.vec.remaining, 0 ; [#uses = 1]
  br i1 %min.epilog.iters.check, label %forbody.preheader, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vector.main.loop.iter.check, %vec.epilog.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ] ; [#uses = 1, type = i64]
  %n.vec12 = and i64 %length_arg, -16             ; [#uses = 3]
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index13 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next15, %vec.epilog.vector.body ] ; [#uses = 3, type = i64]
  %11 = getelementptr inbounds i8, ptr %target_arg, i64 %index13 ; [#uses = 1, type = ptr]
  %12 = getelementptr inbounds i8, ptr %source_arg, i64 %index13 ; [#uses = 1, type = ptr]
  %wide.load14 = load <16 x i8>, ptr %12, align 1 ; [#uses = 1]
  store <16 x i8> %wide.load14, ptr %11, align 1
  %index.next15 = add nuw i64 %index13, 16        ; [#uses = 2]
  %13 = icmp eq i64 %index.next15, %n.vec12       ; [#uses = 1]
  br i1 %13, label %vec.epilog.middle.block, label %vec.epilog.vector.body, !llvm.loop !4

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %cmp.n16 = icmp eq i64 %n.vec12, %length_arg    ; [#uses = 1]
  br i1 %cmp.n16, label %endfor, label %forbody.preheader

forbody.preheader:                                ; preds = %vec.epilog.middle.block, %iter.check, %vec.epilog.iter.check
  %__key2.04.ph = phi i64 [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ], [ %n.vec12, %vec.epilog.middle.block ] ; [#uses = 3, type = i64]
  %xtraiter = and i64 %length_arg, 7              ; [#uses = 2]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0        ; [#uses = 1]
  br i1 %lcmp.mod.not, label %forbody.prol.loopexit, label %forbody.prol

forbody.prol:                                     ; preds = %forbody.preheader, %forbody.prol
  %__key2.04.prol = phi i64 [ %17, %forbody.prol ], [ %__key2.04.ph, %forbody.preheader ] ; [#uses = 3, type = i64]
  %prol.iter = phi i64 [ %prol.iter.next, %forbody.prol ], [ 0, %forbody.preheader ] ; [#uses = 1, type = i64]
  %14 = getelementptr inbounds i8, ptr %target_arg, i64 %__key2.04.prol ; [#uses = 1, type = ptr]
  %15 = getelementptr inbounds i8, ptr %source_arg, i64 %__key2.04.prol ; [#uses = 1, type = ptr]
  %16 = load i8, ptr %15, align 1                 ; [#uses = 1]
  store i8 %16, ptr %14, align 1
  %17 = add nuw i64 %__key2.04.prol, 1            ; [#uses = 2]
  %prol.iter.next = add i64 %prol.iter, 1         ; [#uses = 2]
  %prol.iter.cmp.not = icmp eq i64 %prol.iter.next, %xtraiter ; [#uses = 1]
  br i1 %prol.iter.cmp.not, label %forbody.prol.loopexit, label %forbody.prol, !llvm.loop !5

forbody.prol.loopexit:                            ; preds = %forbody.prol, %forbody.preheader
  %__key2.04.unr = phi i64 [ %__key2.04.ph, %forbody.preheader ], [ %17, %forbody.prol ] ; [#uses = 1, type = i64]
  %18 = sub i64 %__key2.04.ph, %length_arg        ; [#uses = 1]
  %19 = icmp ugt i64 %18, -8                      ; [#uses = 1]
  br i1 %19, label %endfor, label %forbody

forbody:                                          ; preds = %forbody.prol.loopexit, %forbody
  %__key2.04 = phi i64 [ %51, %forbody ], [ %__key2.04.unr, %forbody.prol.loopexit ] ; [#uses = 10, type = i64]
  %20 = getelementptr inbounds i8, ptr %target_arg, i64 %__key2.04 ; [#uses = 1, type = ptr]
  %21 = getelementptr inbounds i8, ptr %source_arg, i64 %__key2.04 ; [#uses = 1, type = ptr]
  %22 = load i8, ptr %21, align 1                 ; [#uses = 1]
  store i8 %22, ptr %20, align 1
  %23 = add nuw i64 %__key2.04, 1                 ; [#uses = 2]
  %24 = getelementptr inbounds i8, ptr %target_arg, i64 %23 ; [#uses = 1, type = ptr]
  %25 = getelementptr inbounds i8, ptr %source_arg, i64 %23 ; [#uses = 1, type = ptr]
  %26 = load i8, ptr %25, align 1                 ; [#uses = 1]
  store i8 %26, ptr %24, align 1
  %27 = add nuw i64 %__key2.04, 2                 ; [#uses = 2]
  %28 = getelementptr inbounds i8, ptr %target_arg, i64 %27 ; [#uses = 1, type = ptr]
  %29 = getelementptr inbounds i8, ptr %source_arg, i64 %27 ; [#uses = 1, type = ptr]
  %30 = load i8, ptr %29, align 1                 ; [#uses = 1]
  store i8 %30, ptr %28, align 1
  %31 = add nuw i64 %__key2.04, 3                 ; [#uses = 2]
  %32 = getelementptr inbounds i8, ptr %target_arg, i64 %31 ; [#uses = 1, type = ptr]
  %33 = getelementptr inbounds i8, ptr %source_arg, i64 %31 ; [#uses = 1, type = ptr]
  %34 = load i8, ptr %33, align 1                 ; [#uses = 1]
  store i8 %34, ptr %32, align 1
  %35 = add nuw i64 %__key2.04, 4                 ; [#uses = 2]
  %36 = getelementptr inbounds i8, ptr %target_arg, i64 %35 ; [#uses = 1, type = ptr]
  %37 = getelementptr inbounds i8, ptr %source_arg, i64 %35 ; [#uses = 1, type = ptr]
  %38 = load i8, ptr %37, align 1                 ; [#uses = 1]
  store i8 %38, ptr %36, align 1
  %39 = add nuw i64 %__key2.04, 5                 ; [#uses = 2]
  %40 = getelementptr inbounds i8, ptr %target_arg, i64 %39 ; [#uses = 1, type = ptr]
  %41 = getelementptr inbounds i8, ptr %source_arg, i64 %39 ; [#uses = 1, type = ptr]
  %42 = load i8, ptr %41, align 1                 ; [#uses = 1]
  store i8 %42, ptr %40, align 1
  %43 = add nuw i64 %__key2.04, 6                 ; [#uses = 2]
  %44 = getelementptr inbounds i8, ptr %target_arg, i64 %43 ; [#uses = 1, type = ptr]
  %45 = getelementptr inbounds i8, ptr %source_arg, i64 %43 ; [#uses = 1, type = ptr]
  %46 = load i8, ptr %45, align 1                 ; [#uses = 1]
  store i8 %46, ptr %44, align 1
  %47 = add nuw i64 %__key2.04, 7                 ; [#uses = 2]
  %48 = getelementptr inbounds i8, ptr %target_arg, i64 %47 ; [#uses = 1, type = ptr]
  %49 = getelementptr inbounds i8, ptr %source_arg, i64 %47 ; [#uses = 1, type = ptr]
  %50 = load i8, ptr %49, align 1                 ; [#uses = 1]
  store i8 %50, ptr %48, align 1
  %51 = add nuw i64 %__key2.04, 8                 ; [#uses = 2]
  %exitcond.not.7 = icmp eq i64 %51, %length_arg  ; [#uses = 1]
  br i1 %exitcond.not.7, label %endfor, label %forbody, !llvm.loop !7

endfor:                                           ; preds = %forbody.prol.loopexit, %forbody, %middle.block, %vec.epilog.middle.block, %0
  ret i1 true
}

; [#uses = 0]
; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) uwtable
define noundef zeroext i1 @copy_restrict(ptr noalias nocapture readonly %source_arg, ptr noalias nocapture writeonly %target_arg, i64 %length_arg) local_unnamed_addr #1 {
  %.not = icmp eq i64 %length_arg, 0              ; [#uses = 1]
  br i1 %.not, label %endfor, label %forbody.preheader

forbody.preheader:                                ; preds = %0
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 1 %target_arg, ptr align 1 %source_arg, i64 %length_arg, i1 false)
  br label %endfor

endfor:                                           ; preds = %forbody.preheader, %0
  ret i1 true
}

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define double @sum_f32_f64_strict(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #2 {
  %.not = icmp eq i64 %length_arg, 0              ; [#uses = 1]
  br i1 %.not, label %endfor, label %forbody.preheader

forbody.preheader:                                ; preds = %0
  %xtraiter = and i64 %length_arg, 7              ; [#uses = 2]
  %1 = icmp ult i64 %length_arg, 8                ; [#uses = 1]
  br i1 %1, label %endfor.loopexit.unr-lcssa, label %forbody.preheader.new

forbody.preheader.new:                            ; preds = %forbody.preheader
  %unroll_iter = and i64 %length_arg, -8          ; [#uses = 1]
  br label %forbody

forbody:                                          ; preds = %forbody, %forbody.preheader.new
  %total.06 = phi double [ 0.000000e+00, %forbody.preheader.new ], [ %40, %forbody ] ; [#uses = 1, type = double]
  %__key6.05 = phi i64 [ 0, %forbody.preheader.new ], [ %41, %forbody ] ; [#uses = 9, type = i64]
  %niter = phi i64 [ 0, %forbody.preheader.new ], [ %niter.next.7, %forbody ] ; [#uses = 1, type = i64]
  %2 = getelementptr inbounds float, ptr %source_arg, i64 %__key6.05 ; [#uses = 1, type = ptr]
  %3 = load float, ptr %2, align 4                ; [#uses = 1]
  %4 = fpext float %3 to double                   ; [#uses = 1]
  %5 = fadd double %total.06, %4                  ; [#uses = 1]
  %6 = or disjoint i64 %__key6.05, 1              ; [#uses = 1]
  %7 = getelementptr inbounds float, ptr %source_arg, i64 %6 ; [#uses = 1, type = ptr]
  %8 = load float, ptr %7, align 4                ; [#uses = 1]
  %9 = fpext float %8 to double                   ; [#uses = 1]
  %10 = fadd double %5, %9                        ; [#uses = 1]
  %11 = or disjoint i64 %__key6.05, 2             ; [#uses = 1]
  %12 = getelementptr inbounds float, ptr %source_arg, i64 %11 ; [#uses = 1, type = ptr]
  %13 = load float, ptr %12, align 4              ; [#uses = 1]
  %14 = fpext float %13 to double                 ; [#uses = 1]
  %15 = fadd double %10, %14                      ; [#uses = 1]
  %16 = or disjoint i64 %__key6.05, 3             ; [#uses = 1]
  %17 = getelementptr inbounds float, ptr %source_arg, i64 %16 ; [#uses = 1, type = ptr]
  %18 = load float, ptr %17, align 4              ; [#uses = 1]
  %19 = fpext float %18 to double                 ; [#uses = 1]
  %20 = fadd double %15, %19                      ; [#uses = 1]
  %21 = or disjoint i64 %__key6.05, 4             ; [#uses = 1]
  %22 = getelementptr inbounds float, ptr %source_arg, i64 %21 ; [#uses = 1, type = ptr]
  %23 = load float, ptr %22, align 4              ; [#uses = 1]
  %24 = fpext float %23 to double                 ; [#uses = 1]
  %25 = fadd double %20, %24                      ; [#uses = 1]
  %26 = or disjoint i64 %__key6.05, 5             ; [#uses = 1]
  %27 = getelementptr inbounds float, ptr %source_arg, i64 %26 ; [#uses = 1, type = ptr]
  %28 = load float, ptr %27, align 4              ; [#uses = 1]
  %29 = fpext float %28 to double                 ; [#uses = 1]
  %30 = fadd double %25, %29                      ; [#uses = 1]
  %31 = or disjoint i64 %__key6.05, 6             ; [#uses = 1]
  %32 = getelementptr inbounds float, ptr %source_arg, i64 %31 ; [#uses = 1, type = ptr]
  %33 = load float, ptr %32, align 4              ; [#uses = 1]
  %34 = fpext float %33 to double                 ; [#uses = 1]
  %35 = fadd double %30, %34                      ; [#uses = 1]
  %36 = or disjoint i64 %__key6.05, 7             ; [#uses = 1]
  %37 = getelementptr inbounds float, ptr %source_arg, i64 %36 ; [#uses = 1, type = ptr]
  %38 = load float, ptr %37, align 4              ; [#uses = 1]
  %39 = fpext float %38 to double                 ; [#uses = 1]
  %40 = fadd double %35, %39                      ; [#uses = 3]
  %41 = add nuw i64 %__key6.05, 8                 ; [#uses = 2]
  %niter.next.7 = add i64 %niter, 8               ; [#uses = 2]
  %niter.ncmp.7 = icmp eq i64 %niter.next.7, %unroll_iter ; [#uses = 1]
  br i1 %niter.ncmp.7, label %endfor.loopexit.unr-lcssa, label %forbody

endfor.loopexit.unr-lcssa:                        ; preds = %forbody, %forbody.preheader
  %.lcssa.ph = phi double [ poison, %forbody.preheader ], [ %40, %forbody ] ; [#uses = 1, type = double]
  %total.06.unr = phi double [ 0.000000e+00, %forbody.preheader ], [ %40, %forbody ] ; [#uses = 1, type = double]
  %__key6.05.unr = phi i64 [ 0, %forbody.preheader ], [ %41, %forbody ] ; [#uses = 1, type = i64]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0        ; [#uses = 1]
  br i1 %lcmp.mod.not, label %endfor, label %forbody.epil

forbody.epil:                                     ; preds = %endfor.loopexit.unr-lcssa, %forbody.epil
  %total.06.epil = phi double [ %45, %forbody.epil ], [ %total.06.unr, %endfor.loopexit.unr-lcssa ] ; [#uses = 1, type = double]
  %__key6.05.epil = phi i64 [ %46, %forbody.epil ], [ %__key6.05.unr, %endfor.loopexit.unr-lcssa ] ; [#uses = 2, type = i64]
  %epil.iter = phi i64 [ %epil.iter.next, %forbody.epil ], [ 0, %endfor.loopexit.unr-lcssa ] ; [#uses = 1, type = i64]
  %42 = getelementptr inbounds float, ptr %source_arg, i64 %__key6.05.epil ; [#uses = 1, type = ptr]
  %43 = load float, ptr %42, align 4              ; [#uses = 1]
  %44 = fpext float %43 to double                 ; [#uses = 1]
  %45 = fadd double %total.06.epil, %44           ; [#uses = 2]
  %46 = add nuw i64 %__key6.05.epil, 1            ; [#uses = 1]
  %epil.iter.next = add i64 %epil.iter, 1         ; [#uses = 2]
  %epil.iter.cmp.not = icmp eq i64 %epil.iter.next, %xtraiter ; [#uses = 1]
  br i1 %epil.iter.cmp.not, label %endfor, label %forbody.epil, !llvm.loop !8

endfor:                                           ; preds = %endfor.loopexit.unr-lcssa, %forbody.epil, %0
  %total.0.lcssa = phi double [ 0.000000e+00, %0 ], [ %.lcssa.ph, %endfor.loopexit.unr-lcssa ], [ %45, %forbody.epil ] ; [#uses = 1, type = double]
  ret double %total.0.lcssa
}

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define double @sum_f32_f64_fastmath(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #3 {
  %.not = icmp eq i64 %length_arg, 0              ; [#uses = 1]
  br i1 %.not, label %endfor, label %forbody.preheader

forbody.preheader:                                ; preds = %0
  %min.iters.check = icmp ult i64 %length_arg, 16 ; [#uses = 1]
  br i1 %min.iters.check, label %forbody.preheader15, label %vector.ph

vector.ph:                                        ; preds = %forbody.preheader
  %n.vec = and i64 %length_arg, -16               ; [#uses = 3]
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ] ; [#uses = 2, type = i64]
  %vec.phi = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %9, %vector.body ] ; [#uses = 1, type = <4 x double>]
  %vec.phi7 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %10, %vector.body ] ; [#uses = 1, type = <4 x double>]
  %vec.phi8 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %11, %vector.body ] ; [#uses = 1, type = <4 x double>]
  %vec.phi9 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %12, %vector.body ] ; [#uses = 1, type = <4 x double>]
  %1 = getelementptr inbounds float, ptr %source_arg, i64 %index ; [#uses = 4, type = ptr]
  %2 = getelementptr inbounds i8, ptr %1, i64 16  ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %1, i64 32  ; [#uses = 1, type = ptr]
  %4 = getelementptr inbounds i8, ptr %1, i64 48  ; [#uses = 1, type = ptr]
  %wide.load = load <4 x float>, ptr %1, align 4  ; [#uses = 1]
  %wide.load10 = load <4 x float>, ptr %2, align 4 ; [#uses = 1]
  %wide.load11 = load <4 x float>, ptr %3, align 4 ; [#uses = 1]
  %wide.load12 = load <4 x float>, ptr %4, align 4 ; [#uses = 1]
  %5 = fpext <4 x float> %wide.load to <4 x double> ; [#uses = 1]
  %6 = fpext <4 x float> %wide.load10 to <4 x double> ; [#uses = 1]
  %7 = fpext <4 x float> %wide.load11 to <4 x double> ; [#uses = 1]
  %8 = fpext <4 x float> %wide.load12 to <4 x double> ; [#uses = 1]
  %9 = fadd fast <4 x double> %vec.phi, %5        ; [#uses = 2]
  %10 = fadd fast <4 x double> %vec.phi7, %6      ; [#uses = 2]
  %11 = fadd fast <4 x double> %vec.phi8, %7      ; [#uses = 2]
  %12 = fadd fast <4 x double> %vec.phi9, %8      ; [#uses = 2]
  %index.next = add nuw i64 %index, 16            ; [#uses = 2]
  %13 = icmp eq i64 %index.next, %n.vec           ; [#uses = 1]
  br i1 %13, label %middle.block, label %vector.body, !llvm.loop !9

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd fast <4 x double> %10, %9       ; [#uses = 1]
  %bin.rdx13 = fadd fast <4 x double> %11, %bin.rdx ; [#uses = 1]
  %bin.rdx14 = fadd fast <4 x double> %12, %bin.rdx13 ; [#uses = 1]
  %14 = tail call fast double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx14) ; [#uses = 2]
  %cmp.n = icmp eq i64 %n.vec, %length_arg        ; [#uses = 1]
  br i1 %cmp.n, label %endfor, label %forbody.preheader15

forbody.preheader15:                              ; preds = %middle.block, %forbody.preheader
  %total.06.ph = phi double [ 0.000000e+00, %forbody.preheader ], [ %14, %middle.block ] ; [#uses = 1, type = double]
  %__key8.05.ph = phi i64 [ 0, %forbody.preheader ], [ %n.vec, %middle.block ] ; [#uses = 1, type = i64]
  br label %forbody

forbody:                                          ; preds = %forbody.preheader15, %forbody
  %total.06 = phi double [ %18, %forbody ], [ %total.06.ph, %forbody.preheader15 ] ; [#uses = 1, type = double]
  %__key8.05 = phi i64 [ %19, %forbody ], [ %__key8.05.ph, %forbody.preheader15 ] ; [#uses = 2, type = i64]
  %15 = getelementptr inbounds float, ptr %source_arg, i64 %__key8.05 ; [#uses = 1, type = ptr]
  %16 = load float, ptr %15, align 4              ; [#uses = 1]
  %17 = fpext float %16 to double                 ; [#uses = 1]
  %18 = fadd fast double %total.06, %17           ; [#uses = 2]
  %19 = add nuw i64 %__key8.05, 1                 ; [#uses = 2]
  %exitcond.not = icmp eq i64 %19, %length_arg    ; [#uses = 1]
  br i1 %exitcond.not, label %endfor, label %forbody, !llvm.loop !10

endfor:                                           ; preds = %forbody, %middle.block, %0
  %total.0.lcssa = phi double [ 0.000000e+00, %0 ], [ %14, %middle.block ], [ %18, %forbody ] ; [#uses = 1, type = double]
  ret double %total.0.lcssa
}

; [#uses = 1]
; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #4

; [#uses = 1]
; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.vector.reduce.fadd.v4f64(double, <4 x double>) #5

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: readwrite) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" }
attributes #2 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" }
attributes #3 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" "unsafe-fp-math"="true" }
attributes #4 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.ident = !{!0}

!0 = !{!"ldc version 1.41.0"}
!1 = distinct !{!1, !2, !3}
!2 = !{!"llvm.loop.isvectorized", i32 1}
!3 = !{!"llvm.loop.unroll.runtime.disable"}
!4 = distinct !{!4, !2, !3}
!5 = distinct !{!5, !6}
!6 = !{!"llvm.loop.unroll.disable"}
!7 = distinct !{!7, !2}
!8 = distinct !{!8, !6}
!9 = distinct !{!9, !2, !3}
!10 = distinct !{!10, !3, !2}
