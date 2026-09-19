; ModuleID = '/tmp/d-imagery-e5_3e-alias/alias_probe.d'
source_filename = "/tmp/d-imagery-e5_3e-alias/alias_probe.d"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%0 = type { i32, i32, [12 x i8] }

@_D11alias_probe12__ModuleInfoZ = global %0 { i32 -2147483644, i32 0, [12 x i8] c"alias_probe\00" } ; [#uses = 1]
@_D11alias_probe11__moduleRefZ = linkonce_odr hidden global ptr @_D11alias_probe12__ModuleInfoZ, section "__minfo" ; [#uses = 1]
@llvm.used = appending global [1 x ptr] [ptr @_D11alias_probe11__moduleRefZ], section "llvm.metadata" ; [#uses = 0]

; [#uses = 0]
; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite) uwtable
define void @rawConvertUnknown(ptr nocapture readonly %source_arg, ptr nocapture writeonly %target_arg, i64 %elementCount_arg) local_unnamed_addr #0 {
  %.not = icmp eq i64 %elementCount_arg, 0        ; [#uses = 1]
  br i1 %.not, label %endfor, label %forbody.preheader

forbody.preheader:                                ; preds = %0
  %min.iters.check = icmp ult i64 %elementCount_arg, 32 ; [#uses = 1]
  br i1 %min.iters.check, label %forbody.preheader9, label %vector.memcheck

vector.memcheck:                                  ; preds = %forbody.preheader
  %1 = shl i64 %elementCount_arg, 2               ; [#uses = 1]
  %scevgep = getelementptr i8, ptr %target_arg, i64 %1 ; [#uses = 1, type = ptr]
  %scevgep5 = getelementptr i8, ptr %source_arg, i64 %elementCount_arg ; [#uses = 1, type = ptr]
  %bound0 = icmp ugt ptr %scevgep5, %target_arg   ; [#uses = 1]
  %bound1 = icmp ugt ptr %scevgep, %source_arg    ; [#uses = 1]
  %found.conflict = and i1 %bound0, %bound1       ; [#uses = 1]
  br i1 %found.conflict, label %forbody.preheader9, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %elementCount_arg, -32         ; [#uses = 3]
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ] ; [#uses = 3, type = i64]
  %2 = getelementptr inbounds float, ptr %target_arg, i64 %index ; [#uses = 4, type = ptr]
  %3 = getelementptr inbounds i8, ptr %source_arg, i64 %index ; [#uses = 4, type = ptr]
  %4 = getelementptr inbounds i8, ptr %3, i64 8   ; [#uses = 1, type = ptr]
  %5 = getelementptr inbounds i8, ptr %3, i64 16  ; [#uses = 1, type = ptr]
  %6 = getelementptr inbounds i8, ptr %3, i64 24  ; [#uses = 1, type = ptr]
  %wide.load = load <8 x i8>, ptr %3, align 1, !alias.scope !1 ; [#uses = 1]
  %wide.load6 = load <8 x i8>, ptr %4, align 1, !alias.scope !1 ; [#uses = 1]
  %wide.load7 = load <8 x i8>, ptr %5, align 1, !alias.scope !1 ; [#uses = 1]
  %wide.load8 = load <8 x i8>, ptr %6, align 1, !alias.scope !1 ; [#uses = 1]
  %7 = uitofp <8 x i8> %wide.load to <8 x float>  ; [#uses = 1]
  %8 = uitofp <8 x i8> %wide.load6 to <8 x float> ; [#uses = 1]
  %9 = uitofp <8 x i8> %wide.load7 to <8 x float> ; [#uses = 1]
  %10 = uitofp <8 x i8> %wide.load8 to <8 x float> ; [#uses = 1]
  %11 = getelementptr inbounds i8, ptr %2, i64 32 ; [#uses = 1, type = ptr]
  %12 = getelementptr inbounds i8, ptr %2, i64 64 ; [#uses = 1, type = ptr]
  %13 = getelementptr inbounds i8, ptr %2, i64 96 ; [#uses = 1, type = ptr]
  store <8 x float> %7, ptr %2, align 4, !alias.scope !4, !noalias !1
  store <8 x float> %8, ptr %11, align 4, !alias.scope !4, !noalias !1
  store <8 x float> %9, ptr %12, align 4, !alias.scope !4, !noalias !1
  store <8 x float> %10, ptr %13, align 4, !alias.scope !4, !noalias !1
  %index.next = add nuw i64 %index, 32            ; [#uses = 2]
  %14 = icmp eq i64 %index.next, %n.vec           ; [#uses = 1]
  br i1 %14, label %middle.block, label %vector.body, !llvm.loop !6

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %elementCount_arg  ; [#uses = 1]
  br i1 %cmp.n, label %endfor, label %forbody.preheader9

forbody.preheader9:                               ; preds = %middle.block, %vector.memcheck, %forbody.preheader
  %__key2.04.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %forbody.preheader ], [ %n.vec, %middle.block ] ; [#uses = 3, type = i64]
  %xtraiter = and i64 %elementCount_arg, 7        ; [#uses = 2]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0        ; [#uses = 1]
  br i1 %lcmp.mod.not, label %forbody.prol.loopexit, label %forbody.prol

forbody.prol:                                     ; preds = %forbody.preheader9, %forbody.prol
  %__key2.04.prol = phi i64 [ %19, %forbody.prol ], [ %__key2.04.ph, %forbody.preheader9 ] ; [#uses = 3, type = i64]
  %prol.iter = phi i64 [ %prol.iter.next, %forbody.prol ], [ 0, %forbody.preheader9 ] ; [#uses = 1, type = i64]
  %15 = getelementptr inbounds float, ptr %target_arg, i64 %__key2.04.prol ; [#uses = 1, type = ptr]
  %16 = getelementptr inbounds i8, ptr %source_arg, i64 %__key2.04.prol ; [#uses = 1, type = ptr]
  %17 = load i8, ptr %16, align 1                 ; [#uses = 1]
  %18 = uitofp i8 %17 to float                    ; [#uses = 1]
  store float %18, ptr %15, align 4
  %19 = add nuw i64 %__key2.04.prol, 1            ; [#uses = 2]
  %prol.iter.next = add i64 %prol.iter, 1         ; [#uses = 2]
  %prol.iter.cmp.not = icmp eq i64 %prol.iter.next, %xtraiter ; [#uses = 1]
  br i1 %prol.iter.cmp.not, label %forbody.prol.loopexit, label %forbody.prol, !llvm.loop !9

forbody.prol.loopexit:                            ; preds = %forbody.prol, %forbody.preheader9
  %__key2.04.unr = phi i64 [ %__key2.04.ph, %forbody.preheader9 ], [ %19, %forbody.prol ] ; [#uses = 1, type = i64]
  %20 = sub i64 %__key2.04.ph, %elementCount_arg  ; [#uses = 1]
  %21 = icmp ugt i64 %20, -8                      ; [#uses = 1]
  br i1 %21, label %endfor, label %forbody

forbody:                                          ; preds = %forbody.prol.loopexit, %forbody
  %__key2.04 = phi i64 [ %61, %forbody ], [ %__key2.04.unr, %forbody.prol.loopexit ] ; [#uses = 10, type = i64]
  %22 = getelementptr inbounds float, ptr %target_arg, i64 %__key2.04 ; [#uses = 1, type = ptr]
  %23 = getelementptr inbounds i8, ptr %source_arg, i64 %__key2.04 ; [#uses = 1, type = ptr]
  %24 = load i8, ptr %23, align 1                 ; [#uses = 1]
  %25 = uitofp i8 %24 to float                    ; [#uses = 1]
  store float %25, ptr %22, align 4
  %26 = add nuw i64 %__key2.04, 1                 ; [#uses = 2]
  %27 = getelementptr inbounds float, ptr %target_arg, i64 %26 ; [#uses = 1, type = ptr]
  %28 = getelementptr inbounds i8, ptr %source_arg, i64 %26 ; [#uses = 1, type = ptr]
  %29 = load i8, ptr %28, align 1                 ; [#uses = 1]
  %30 = uitofp i8 %29 to float                    ; [#uses = 1]
  store float %30, ptr %27, align 4
  %31 = add nuw i64 %__key2.04, 2                 ; [#uses = 2]
  %32 = getelementptr inbounds float, ptr %target_arg, i64 %31 ; [#uses = 1, type = ptr]
  %33 = getelementptr inbounds i8, ptr %source_arg, i64 %31 ; [#uses = 1, type = ptr]
  %34 = load i8, ptr %33, align 1                 ; [#uses = 1]
  %35 = uitofp i8 %34 to float                    ; [#uses = 1]
  store float %35, ptr %32, align 4
  %36 = add nuw i64 %__key2.04, 3                 ; [#uses = 2]
  %37 = getelementptr inbounds float, ptr %target_arg, i64 %36 ; [#uses = 1, type = ptr]
  %38 = getelementptr inbounds i8, ptr %source_arg, i64 %36 ; [#uses = 1, type = ptr]
  %39 = load i8, ptr %38, align 1                 ; [#uses = 1]
  %40 = uitofp i8 %39 to float                    ; [#uses = 1]
  store float %40, ptr %37, align 4
  %41 = add nuw i64 %__key2.04, 4                 ; [#uses = 2]
  %42 = getelementptr inbounds float, ptr %target_arg, i64 %41 ; [#uses = 1, type = ptr]
  %43 = getelementptr inbounds i8, ptr %source_arg, i64 %41 ; [#uses = 1, type = ptr]
  %44 = load i8, ptr %43, align 1                 ; [#uses = 1]
  %45 = uitofp i8 %44 to float                    ; [#uses = 1]
  store float %45, ptr %42, align 4
  %46 = add nuw i64 %__key2.04, 5                 ; [#uses = 2]
  %47 = getelementptr inbounds float, ptr %target_arg, i64 %46 ; [#uses = 1, type = ptr]
  %48 = getelementptr inbounds i8, ptr %source_arg, i64 %46 ; [#uses = 1, type = ptr]
  %49 = load i8, ptr %48, align 1                 ; [#uses = 1]
  %50 = uitofp i8 %49 to float                    ; [#uses = 1]
  store float %50, ptr %47, align 4
  %51 = add nuw i64 %__key2.04, 6                 ; [#uses = 2]
  %52 = getelementptr inbounds float, ptr %target_arg, i64 %51 ; [#uses = 1, type = ptr]
  %53 = getelementptr inbounds i8, ptr %source_arg, i64 %51 ; [#uses = 1, type = ptr]
  %54 = load i8, ptr %53, align 1                 ; [#uses = 1]
  %55 = uitofp i8 %54 to float                    ; [#uses = 1]
  store float %55, ptr %52, align 4
  %56 = add nuw i64 %__key2.04, 7                 ; [#uses = 2]
  %57 = getelementptr inbounds float, ptr %target_arg, i64 %56 ; [#uses = 1, type = ptr]
  %58 = getelementptr inbounds i8, ptr %source_arg, i64 %56 ; [#uses = 1, type = ptr]
  %59 = load i8, ptr %58, align 1                 ; [#uses = 1]
  %60 = uitofp i8 %59 to float                    ; [#uses = 1]
  store float %60, ptr %57, align 4
  %61 = add nuw i64 %__key2.04, 8                 ; [#uses = 2]
  %exitcond.not.7 = icmp eq i64 %61, %elementCount_arg ; [#uses = 1]
  br i1 %exitcond.not.7, label %endfor, label %forbody, !llvm.loop !11

endfor:                                           ; preds = %forbody.prol.loopexit, %forbody, %middle.block, %0
  ret void
}

; [#uses = 0]
; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite) uwtable
define void @rawConvertRestrict(ptr noalias nocapture readonly %source_arg, ptr noalias nocapture writeonly %target_arg, i64 %elementCount_arg) local_unnamed_addr #0 {
  %.not = icmp eq i64 %elementCount_arg, 0        ; [#uses = 1]
  br i1 %.not, label %endfor, label %forbody.preheader

forbody.preheader:                                ; preds = %0
  %min.iters.check = icmp ult i64 %elementCount_arg, 32 ; [#uses = 1]
  br i1 %min.iters.check, label %forbody.preheader8, label %vector.ph

vector.ph:                                        ; preds = %forbody.preheader
  %n.vec = and i64 %elementCount_arg, -32         ; [#uses = 3]
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ] ; [#uses = 3, type = i64]
  %1 = getelementptr inbounds float, ptr %target_arg, i64 %index ; [#uses = 4, type = ptr]
  %2 = getelementptr inbounds i8, ptr %source_arg, i64 %index ; [#uses = 4, type = ptr]
  %3 = getelementptr inbounds i8, ptr %2, i64 8   ; [#uses = 1, type = ptr]
  %4 = getelementptr inbounds i8, ptr %2, i64 16  ; [#uses = 1, type = ptr]
  %5 = getelementptr inbounds i8, ptr %2, i64 24  ; [#uses = 1, type = ptr]
  %wide.load = load <8 x i8>, ptr %2, align 1     ; [#uses = 1]
  %wide.load5 = load <8 x i8>, ptr %3, align 1    ; [#uses = 1]
  %wide.load6 = load <8 x i8>, ptr %4, align 1    ; [#uses = 1]
  %wide.load7 = load <8 x i8>, ptr %5, align 1    ; [#uses = 1]
  %6 = uitofp <8 x i8> %wide.load to <8 x float>  ; [#uses = 1]
  %7 = uitofp <8 x i8> %wide.load5 to <8 x float> ; [#uses = 1]
  %8 = uitofp <8 x i8> %wide.load6 to <8 x float> ; [#uses = 1]
  %9 = uitofp <8 x i8> %wide.load7 to <8 x float> ; [#uses = 1]
  %10 = getelementptr inbounds i8, ptr %1, i64 32 ; [#uses = 1, type = ptr]
  %11 = getelementptr inbounds i8, ptr %1, i64 64 ; [#uses = 1, type = ptr]
  %12 = getelementptr inbounds i8, ptr %1, i64 96 ; [#uses = 1, type = ptr]
  store <8 x float> %6, ptr %1, align 4
  store <8 x float> %7, ptr %10, align 4
  store <8 x float> %8, ptr %11, align 4
  store <8 x float> %9, ptr %12, align 4
  %index.next = add nuw i64 %index, 32            ; [#uses = 2]
  %13 = icmp eq i64 %index.next, %n.vec           ; [#uses = 1]
  br i1 %13, label %middle.block, label %vector.body, !llvm.loop !12

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %elementCount_arg  ; [#uses = 1]
  br i1 %cmp.n, label %endfor, label %forbody.preheader8

forbody.preheader8:                               ; preds = %middle.block, %forbody.preheader
  %__key4.04.ph = phi i64 [ 0, %forbody.preheader ], [ %n.vec, %middle.block ] ; [#uses = 1, type = i64]
  br label %forbody

forbody:                                          ; preds = %forbody.preheader8, %forbody
  %__key4.04 = phi i64 [ %18, %forbody ], [ %__key4.04.ph, %forbody.preheader8 ] ; [#uses = 3, type = i64]
  %14 = getelementptr inbounds float, ptr %target_arg, i64 %__key4.04 ; [#uses = 1, type = ptr]
  %15 = getelementptr inbounds i8, ptr %source_arg, i64 %__key4.04 ; [#uses = 1, type = ptr]
  %16 = load i8, ptr %15, align 1                 ; [#uses = 1]
  %17 = uitofp i8 %16 to float                    ; [#uses = 1]
  store float %17, ptr %14, align 4
  %18 = add nuw i64 %__key4.04, 1                 ; [#uses = 2]
  %exitcond.not = icmp eq i64 %18, %elementCount_arg ; [#uses = 1]
  br i1 %exitcond.not, label %endfor, label %forbody, !llvm.loop !13

endfor:                                           ; preds = %forbody, %middle.block, %0
  ret void
}

attributes #0 = { nofree noinline norecurse nosync nounwind memory(argmem: readwrite) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" }

!llvm.ident = !{!0}

!0 = !{!"ldc version 1.41.0"}
!1 = !{!2}
!2 = distinct !{!2, !3}
!3 = distinct !{!3, !"LVerDomain"}
!4 = !{!5}
!5 = distinct !{!5, !3}
!6 = distinct !{!6, !7, !8}
!7 = !{!"llvm.loop.isvectorized", i32 1}
!8 = !{!"llvm.loop.unroll.runtime.disable"}
!9 = distinct !{!9, !10}
!10 = !{!"llvm.loop.unroll.disable"}
!11 = distinct !{!11, !7}
!12 = distinct !{!12, !7, !8}
!13 = distinct !{!13, !8, !7}
