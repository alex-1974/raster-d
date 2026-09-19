; ModuleID = '/tmp/d-imagery-e4-fixed-lane-20260917-173733/lane_probe.d'
source_filename = "/tmp/d-imagery-e4-fixed-lane-20260917-173733/lane_probe.d"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%0 = type { i32, i32, [41 x i8] }

@_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ = global %0 { i32 -2147483644, i32 0, [41 x i8] c"imagery.raster.internal.fixed_lane_probe\00" } ; [#uses = 1]
@_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ = linkonce_odr hidden global ptr @_D7imagery6raster8internal16fixed_lane_probe12__ModuleInfoZ, section "__minfo" ; [#uses = 1]
@llvm.used = appending global [1 x ptr] [ptr @_D7imagery6raster8internal16fixed_lane_probe11__moduleRefZ], section "llvm.metadata" ; [#uses = 0]

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define double @sum_strict(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #0 {
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
  %__key2.05 = phi i64 [ 0, %forbody.preheader.new ], [ %41, %forbody ] ; [#uses = 9, type = i64]
  %niter = phi i64 [ 0, %forbody.preheader.new ], [ %niter.next.7, %forbody ] ; [#uses = 1, type = i64]
  %2 = getelementptr inbounds float, ptr %source_arg, i64 %__key2.05 ; [#uses = 1, type = ptr]
  %3 = load float, ptr %2, align 4                ; [#uses = 1]
  %4 = fpext float %3 to double                   ; [#uses = 1]
  %5 = fadd double %total.06, %4                  ; [#uses = 1]
  %6 = or disjoint i64 %__key2.05, 1              ; [#uses = 1]
  %7 = getelementptr inbounds float, ptr %source_arg, i64 %6 ; [#uses = 1, type = ptr]
  %8 = load float, ptr %7, align 4                ; [#uses = 1]
  %9 = fpext float %8 to double                   ; [#uses = 1]
  %10 = fadd double %5, %9                        ; [#uses = 1]
  %11 = or disjoint i64 %__key2.05, 2             ; [#uses = 1]
  %12 = getelementptr inbounds float, ptr %source_arg, i64 %11 ; [#uses = 1, type = ptr]
  %13 = load float, ptr %12, align 4              ; [#uses = 1]
  %14 = fpext float %13 to double                 ; [#uses = 1]
  %15 = fadd double %10, %14                      ; [#uses = 1]
  %16 = or disjoint i64 %__key2.05, 3             ; [#uses = 1]
  %17 = getelementptr inbounds float, ptr %source_arg, i64 %16 ; [#uses = 1, type = ptr]
  %18 = load float, ptr %17, align 4              ; [#uses = 1]
  %19 = fpext float %18 to double                 ; [#uses = 1]
  %20 = fadd double %15, %19                      ; [#uses = 1]
  %21 = or disjoint i64 %__key2.05, 4             ; [#uses = 1]
  %22 = getelementptr inbounds float, ptr %source_arg, i64 %21 ; [#uses = 1, type = ptr]
  %23 = load float, ptr %22, align 4              ; [#uses = 1]
  %24 = fpext float %23 to double                 ; [#uses = 1]
  %25 = fadd double %20, %24                      ; [#uses = 1]
  %26 = or disjoint i64 %__key2.05, 5             ; [#uses = 1]
  %27 = getelementptr inbounds float, ptr %source_arg, i64 %26 ; [#uses = 1, type = ptr]
  %28 = load float, ptr %27, align 4              ; [#uses = 1]
  %29 = fpext float %28 to double                 ; [#uses = 1]
  %30 = fadd double %25, %29                      ; [#uses = 1]
  %31 = or disjoint i64 %__key2.05, 6             ; [#uses = 1]
  %32 = getelementptr inbounds float, ptr %source_arg, i64 %31 ; [#uses = 1, type = ptr]
  %33 = load float, ptr %32, align 4              ; [#uses = 1]
  %34 = fpext float %33 to double                 ; [#uses = 1]
  %35 = fadd double %30, %34                      ; [#uses = 1]
  %36 = or disjoint i64 %__key2.05, 7             ; [#uses = 1]
  %37 = getelementptr inbounds float, ptr %source_arg, i64 %36 ; [#uses = 1, type = ptr]
  %38 = load float, ptr %37, align 4              ; [#uses = 1]
  %39 = fpext float %38 to double                 ; [#uses = 1]
  %40 = fadd double %35, %39                      ; [#uses = 3]
  %41 = add nuw i64 %__key2.05, 8                 ; [#uses = 2]
  %niter.next.7 = add i64 %niter, 8               ; [#uses = 2]
  %niter.ncmp.7 = icmp eq i64 %niter.next.7, %unroll_iter ; [#uses = 1]
  br i1 %niter.ncmp.7, label %endfor.loopexit.unr-lcssa, label %forbody

endfor.loopexit.unr-lcssa:                        ; preds = %forbody, %forbody.preheader
  %.lcssa.ph = phi double [ poison, %forbody.preheader ], [ %40, %forbody ] ; [#uses = 1, type = double]
  %total.06.unr = phi double [ 0.000000e+00, %forbody.preheader ], [ %40, %forbody ] ; [#uses = 1, type = double]
  %__key2.05.unr = phi i64 [ 0, %forbody.preheader ], [ %41, %forbody ] ; [#uses = 1, type = i64]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0        ; [#uses = 1]
  br i1 %lcmp.mod.not, label %endfor, label %forbody.epil

forbody.epil:                                     ; preds = %endfor.loopexit.unr-lcssa, %forbody.epil
  %total.06.epil = phi double [ %45, %forbody.epil ], [ %total.06.unr, %endfor.loopexit.unr-lcssa ] ; [#uses = 1, type = double]
  %__key2.05.epil = phi i64 [ %46, %forbody.epil ], [ %__key2.05.unr, %endfor.loopexit.unr-lcssa ] ; [#uses = 2, type = i64]
  %epil.iter = phi i64 [ %epil.iter.next, %forbody.epil ], [ 0, %endfor.loopexit.unr-lcssa ] ; [#uses = 1, type = i64]
  %42 = getelementptr inbounds float, ptr %source_arg, i64 %__key2.05.epil ; [#uses = 1, type = ptr]
  %43 = load float, ptr %42, align 4              ; [#uses = 1]
  %44 = fpext float %43 to double                 ; [#uses = 1]
  %45 = fadd double %total.06.epil, %44           ; [#uses = 2]
  %46 = add nuw i64 %__key2.05.epil, 1            ; [#uses = 1]
  %epil.iter.next = add i64 %epil.iter, 1         ; [#uses = 2]
  %epil.iter.cmp.not = icmp eq i64 %epil.iter.next, %xtraiter ; [#uses = 1]
  br i1 %epil.iter.cmp.not, label %endfor, label %forbody.epil, !llvm.loop !1

endfor:                                           ; preds = %endfor.loopexit.unr-lcssa, %forbody.epil, %0
  %total.0.lcssa = phi double [ 0.000000e+00, %0 ], [ %.lcssa.ph, %endfor.loopexit.unr-lcssa ], [ %45, %forbody.epil ] ; [#uses = 1, type = double]
  ret double %total.0.lcssa
}

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define double @sum_fixed_lane4(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #0 {
  %1 = icmp ugt i64 %length_arg, 3                ; [#uses = 1]
  br i1 %1, label %forbody.preheader, label %endfor

forbody.preheader:                                ; preds = %0
  %2 = add i64 %length_arg, -4                    ; [#uses = 3]
  %3 = icmp ult i64 %2, 4                         ; [#uses = 1]
  br i1 %3, label %endfor.loopexit.unr-lcssa, label %forbody.preheader.new

forbody.preheader.new:                            ; preds = %forbody.preheader
  %4 = lshr i64 %2, 2                             ; [#uses = 1]
  %5 = add nuw nsw i64 %4, 1                      ; [#uses = 1]
  %unroll_iter = and i64 %5, 9223372036854775806  ; [#uses = 1]
  br label %forbody

forbody:                                          ; preds = %forbody, %forbody.preheader.new
  %i.028 = phi i64 [ 0, %forbody.preheader.new ], [ %47, %forbody ] ; [#uses = 9, type = i64]
  %6 = phi <2 x double> [ zeroinitializer, %forbody.preheader.new ], [ %45, %forbody ] ; [#uses = 1, type = <2 x double>]
  %7 = phi <2 x double> [ zeroinitializer, %forbody.preheader.new ], [ %46, %forbody ] ; [#uses = 1, type = <2 x double>]
  %niter = phi i64 [ 0, %forbody.preheader.new ], [ %niter.next.1, %forbody ] ; [#uses = 1, type = i64]
  %8 = getelementptr inbounds float, ptr %source_arg, i64 %i.028 ; [#uses = 1, type = ptr]
  %9 = load float, ptr %8, align 4                ; [#uses = 1]
  %10 = or disjoint i64 %i.028, 1                 ; [#uses = 1]
  %11 = getelementptr inbounds float, ptr %source_arg, i64 %10 ; [#uses = 1, type = ptr]
  %12 = load float, ptr %11, align 4              ; [#uses = 1]
  %13 = or disjoint i64 %i.028, 2                 ; [#uses = 1]
  %14 = getelementptr inbounds float, ptr %source_arg, i64 %13 ; [#uses = 1, type = ptr]
  %15 = load float, ptr %14, align 4              ; [#uses = 1]
  %16 = or disjoint i64 %i.028, 3                 ; [#uses = 1]
  %17 = getelementptr inbounds float, ptr %source_arg, i64 %16 ; [#uses = 1, type = ptr]
  %18 = load float, ptr %17, align 4              ; [#uses = 1]
  %19 = insertelement <2 x float> poison, float %9, i64 0 ; [#uses = 1]
  %20 = insertelement <2 x float> %19, float %15, i64 1 ; [#uses = 1]
  %21 = fpext <2 x float> %20 to <2 x double>     ; [#uses = 1]
  %22 = insertelement <2 x float> poison, float %12, i64 0 ; [#uses = 1]
  %23 = insertelement <2 x float> %22, float %18, i64 1 ; [#uses = 1]
  %24 = fpext <2 x float> %23 to <2 x double>     ; [#uses = 1]
  %25 = fadd <2 x double> %6, %21                 ; [#uses = 1]
  %26 = fadd <2 x double> %7, %24                 ; [#uses = 1]
  %27 = or disjoint i64 %i.028, 4                 ; [#uses = 1]
  %28 = getelementptr inbounds float, ptr %source_arg, i64 %27 ; [#uses = 1, type = ptr]
  %29 = load float, ptr %28, align 4              ; [#uses = 1]
  %30 = or disjoint i64 %i.028, 5                 ; [#uses = 1]
  %31 = getelementptr inbounds float, ptr %source_arg, i64 %30 ; [#uses = 1, type = ptr]
  %32 = load float, ptr %31, align 4              ; [#uses = 1]
  %33 = or disjoint i64 %i.028, 6                 ; [#uses = 1]
  %34 = getelementptr inbounds float, ptr %source_arg, i64 %33 ; [#uses = 1, type = ptr]
  %35 = load float, ptr %34, align 4              ; [#uses = 1]
  %36 = or disjoint i64 %i.028, 7                 ; [#uses = 1]
  %37 = getelementptr inbounds float, ptr %source_arg, i64 %36 ; [#uses = 1, type = ptr]
  %38 = load float, ptr %37, align 4              ; [#uses = 1]
  %39 = insertelement <2 x float> poison, float %29, i64 0 ; [#uses = 1]
  %40 = insertelement <2 x float> %39, float %35, i64 1 ; [#uses = 1]
  %41 = fpext <2 x float> %40 to <2 x double>     ; [#uses = 1]
  %42 = insertelement <2 x float> poison, float %32, i64 0 ; [#uses = 1]
  %43 = insertelement <2 x float> %42, float %38, i64 1 ; [#uses = 1]
  %44 = fpext <2 x float> %43 to <2 x double>     ; [#uses = 1]
  %45 = fadd <2 x double> %25, %41                ; [#uses = 3]
  %46 = fadd <2 x double> %26, %44                ; [#uses = 3]
  %47 = add i64 %i.028, 8                         ; [#uses = 3]
  %niter.next.1 = add i64 %niter, 2               ; [#uses = 2]
  %niter.ncmp.1.not = icmp eq i64 %niter.next.1, %unroll_iter ; [#uses = 1]
  br i1 %niter.ncmp.1.not, label %endfor.loopexit.unr-lcssa, label %forbody

endfor.loopexit.unr-lcssa:                        ; preds = %forbody, %forbody.preheader
  %.lcssa53.ph = phi <2 x double> [ poison, %forbody.preheader ], [ %45, %forbody ] ; [#uses = 1, type = <2 x double>]
  %.lcssa52.ph = phi <2 x double> [ poison, %forbody.preheader ], [ %46, %forbody ] ; [#uses = 1, type = <2 x double>]
  %.lcssa51.ph = phi i64 [ poison, %forbody.preheader ], [ %47, %forbody ] ; [#uses = 1, type = i64]
  %i.028.unr = phi i64 [ 0, %forbody.preheader ], [ %47, %forbody ] ; [#uses = 5, type = i64]
  %.unr = phi <2 x double> [ zeroinitializer, %forbody.preheader ], [ %45, %forbody ] ; [#uses = 1, type = <2 x double>]
  %.unr54 = phi <2 x double> [ zeroinitializer, %forbody.preheader ], [ %46, %forbody ] ; [#uses = 1, type = <2 x double>]
  %48 = and i64 %2, 4                             ; [#uses = 1]
  %lcmp.mod.not.not = icmp eq i64 %48, 0          ; [#uses = 1]
  br i1 %lcmp.mod.not.not, label %forbody.epil, label %endfor.loopexit

forbody.epil:                                     ; preds = %endfor.loopexit.unr-lcssa
  %49 = getelementptr inbounds float, ptr %source_arg, i64 %i.028.unr ; [#uses = 1, type = ptr]
  %50 = load float, ptr %49, align 4              ; [#uses = 1]
  %51 = or disjoint i64 %i.028.unr, 1             ; [#uses = 1]
  %52 = getelementptr inbounds float, ptr %source_arg, i64 %51 ; [#uses = 1, type = ptr]
  %53 = load float, ptr %52, align 4              ; [#uses = 1]
  %54 = or disjoint i64 %i.028.unr, 2             ; [#uses = 1]
  %55 = getelementptr inbounds float, ptr %source_arg, i64 %54 ; [#uses = 1, type = ptr]
  %56 = load float, ptr %55, align 4              ; [#uses = 1]
  %57 = or disjoint i64 %i.028.unr, 3             ; [#uses = 1]
  %58 = getelementptr inbounds float, ptr %source_arg, i64 %57 ; [#uses = 1, type = ptr]
  %59 = load float, ptr %58, align 4              ; [#uses = 1]
  %60 = insertelement <2 x float> poison, float %50, i64 0 ; [#uses = 1]
  %61 = insertelement <2 x float> %60, float %56, i64 1 ; [#uses = 1]
  %62 = fpext <2 x float> %61 to <2 x double>     ; [#uses = 1]
  %63 = insertelement <2 x float> poison, float %53, i64 0 ; [#uses = 1]
  %64 = insertelement <2 x float> %63, float %59, i64 1 ; [#uses = 1]
  %65 = fpext <2 x float> %64 to <2 x double>     ; [#uses = 1]
  %66 = fadd <2 x double> %.unr, %62              ; [#uses = 1]
  %67 = fadd <2 x double> %.unr54, %65            ; [#uses = 1]
  %68 = add i64 %i.028.unr, 4                     ; [#uses = 1]
  br label %endfor.loopexit

endfor.loopexit:                                  ; preds = %endfor.loopexit.unr-lcssa, %forbody.epil
  %.lcssa53 = phi <2 x double> [ %.lcssa53.ph, %endfor.loopexit.unr-lcssa ], [ %66, %forbody.epil ] ; [#uses = 1, type = <2 x double>]
  %.lcssa52 = phi <2 x double> [ %.lcssa52.ph, %endfor.loopexit.unr-lcssa ], [ %67, %forbody.epil ] ; [#uses = 1, type = <2 x double>]
  %.lcssa51 = phi i64 [ %.lcssa51.ph, %endfor.loopexit.unr-lcssa ], [ %68, %forbody.epil ] ; [#uses = 1, type = i64]
  %69 = fadd <2 x double> %.lcssa53, %.lcssa52    ; [#uses = 2]
  %shift = shufflevector <2 x double> %69, <2 x double> poison, <2 x i32> <i32 1, i32 poison> ; [#uses = 1]
  %70 = fadd <2 x double> %69, %shift             ; [#uses = 1]
  %71 = extractelement <2 x double> %70, i64 0    ; [#uses = 1]
  br label %endfor

endfor:                                           ; preds = %endfor.loopexit, %0
  %i.0.lcssa = phi i64 [ 0, %0 ], [ %.lcssa51, %endfor.loopexit ] ; [#uses = 5, type = i64]
  %72 = phi double [ 0.000000e+00, %0 ], [ %71, %endfor.loopexit ] ; [#uses = 3, type = double]
  %73 = icmp ult i64 %i.0.lcssa, %length_arg      ; [#uses = 1]
  br i1 %73, label %forbody2.preheader, label %endfor4

forbody2.preheader:                               ; preds = %endfor
  %74 = sub i64 %length_arg, %i.0.lcssa           ; [#uses = 1]
  %xtraiter58 = and i64 %74, 7                    ; [#uses = 2]
  %lcmp.mod59.not = icmp eq i64 %xtraiter58, 0    ; [#uses = 1]
  br i1 %lcmp.mod59.not, label %forbody2.prol.loopexit, label %forbody2.prol

forbody2.prol:                                    ; preds = %forbody2.preheader, %forbody2.prol
  %total.034.prol = phi double [ %78, %forbody2.prol ], [ %72, %forbody2.preheader ] ; [#uses = 1, type = double]
  %i.133.prol = phi i64 [ %79, %forbody2.prol ], [ %i.0.lcssa, %forbody2.preheader ] ; [#uses = 2, type = i64]
  %prol.iter = phi i64 [ %prol.iter.next, %forbody2.prol ], [ 0, %forbody2.preheader ] ; [#uses = 1, type = i64]
  %75 = getelementptr inbounds float, ptr %source_arg, i64 %i.133.prol ; [#uses = 1, type = ptr]
  %76 = load float, ptr %75, align 4              ; [#uses = 1]
  %77 = fpext float %76 to double                 ; [#uses = 1]
  %78 = fadd double %total.034.prol, %77          ; [#uses = 3]
  %79 = add nuw i64 %i.133.prol, 1                ; [#uses = 2]
  %prol.iter.next = add i64 %prol.iter, 1         ; [#uses = 2]
  %prol.iter.cmp.not = icmp eq i64 %prol.iter.next, %xtraiter58 ; [#uses = 1]
  br i1 %prol.iter.cmp.not, label %forbody2.prol.loopexit, label %forbody2.prol, !llvm.loop !3

forbody2.prol.loopexit:                           ; preds = %forbody2.prol, %forbody2.preheader
  %.lcssa.unr = phi double [ poison, %forbody2.preheader ], [ %78, %forbody2.prol ] ; [#uses = 1, type = double]
  %total.034.unr = phi double [ %72, %forbody2.preheader ], [ %78, %forbody2.prol ] ; [#uses = 1, type = double]
  %i.133.unr = phi i64 [ %i.0.lcssa, %forbody2.preheader ], [ %79, %forbody2.prol ] ; [#uses = 1, type = i64]
  %80 = sub i64 %i.0.lcssa, %length_arg           ; [#uses = 1]
  %81 = icmp ugt i64 %80, -8                      ; [#uses = 1]
  br i1 %81, label %endfor4, label %forbody2.preheader.new

forbody2.preheader.new:                           ; preds = %forbody2.prol.loopexit
  %invariant.gep = getelementptr i8, ptr %source_arg, i64 4 ; [#uses = 1, type = ptr]
  %invariant.gep66 = getelementptr i8, ptr %source_arg, i64 8 ; [#uses = 1, type = ptr]
  %invariant.gep68 = getelementptr i8, ptr %source_arg, i64 12 ; [#uses = 1, type = ptr]
  %invariant.gep70 = getelementptr i8, ptr %source_arg, i64 16 ; [#uses = 1, type = ptr]
  %invariant.gep72 = getelementptr i8, ptr %source_arg, i64 20 ; [#uses = 1, type = ptr]
  %invariant.gep74 = getelementptr i8, ptr %source_arg, i64 24 ; [#uses = 1, type = ptr]
  %invariant.gep76 = getelementptr i8, ptr %source_arg, i64 28 ; [#uses = 1, type = ptr]
  br label %forbody2

forbody2:                                         ; preds = %forbody2, %forbody2.preheader.new
  %total.034 = phi double [ %total.034.unr, %forbody2.preheader.new ], [ %106, %forbody2 ] ; [#uses = 1, type = double]
  %i.133 = phi i64 [ %i.133.unr, %forbody2.preheader.new ], [ %107, %forbody2 ] ; [#uses = 9, type = i64]
  %82 = getelementptr inbounds float, ptr %source_arg, i64 %i.133 ; [#uses = 1, type = ptr]
  %83 = load float, ptr %82, align 4              ; [#uses = 1]
  %84 = fpext float %83 to double                 ; [#uses = 1]
  %85 = fadd double %total.034, %84               ; [#uses = 1]
  %gep = getelementptr float, ptr %invariant.gep, i64 %i.133 ; [#uses = 1, type = ptr]
  %86 = load float, ptr %gep, align 4             ; [#uses = 1]
  %87 = fpext float %86 to double                 ; [#uses = 1]
  %88 = fadd double %85, %87                      ; [#uses = 1]
  %gep67 = getelementptr float, ptr %invariant.gep66, i64 %i.133 ; [#uses = 1, type = ptr]
  %89 = load float, ptr %gep67, align 4           ; [#uses = 1]
  %90 = fpext float %89 to double                 ; [#uses = 1]
  %91 = fadd double %88, %90                      ; [#uses = 1]
  %gep69 = getelementptr float, ptr %invariant.gep68, i64 %i.133 ; [#uses = 1, type = ptr]
  %92 = load float, ptr %gep69, align 4           ; [#uses = 1]
  %93 = fpext float %92 to double                 ; [#uses = 1]
  %94 = fadd double %91, %93                      ; [#uses = 1]
  %gep71 = getelementptr float, ptr %invariant.gep70, i64 %i.133 ; [#uses = 1, type = ptr]
  %95 = load float, ptr %gep71, align 4           ; [#uses = 1]
  %96 = fpext float %95 to double                 ; [#uses = 1]
  %97 = fadd double %94, %96                      ; [#uses = 1]
  %gep73 = getelementptr float, ptr %invariant.gep72, i64 %i.133 ; [#uses = 1, type = ptr]
  %98 = load float, ptr %gep73, align 4           ; [#uses = 1]
  %99 = fpext float %98 to double                 ; [#uses = 1]
  %100 = fadd double %97, %99                     ; [#uses = 1]
  %gep75 = getelementptr float, ptr %invariant.gep74, i64 %i.133 ; [#uses = 1, type = ptr]
  %101 = load float, ptr %gep75, align 4          ; [#uses = 1]
  %102 = fpext float %101 to double               ; [#uses = 1]
  %103 = fadd double %100, %102                   ; [#uses = 1]
  %gep77 = getelementptr float, ptr %invariant.gep76, i64 %i.133 ; [#uses = 1, type = ptr]
  %104 = load float, ptr %gep77, align 4          ; [#uses = 1]
  %105 = fpext float %104 to double               ; [#uses = 1]
  %106 = fadd double %103, %105                   ; [#uses = 2]
  %107 = add nuw i64 %i.133, 8                    ; [#uses = 2]
  %exitcond.not.7 = icmp eq i64 %107, %length_arg ; [#uses = 1]
  br i1 %exitcond.not.7, label %endfor4, label %forbody2

endfor4:                                          ; preds = %forbody2.prol.loopexit, %forbody2, %endfor
  %total.0.lcssa = phi double [ %72, %endfor ], [ %.lcssa.unr, %forbody2.prol.loopexit ], [ %106, %forbody2 ] ; [#uses = 1, type = double]
  ret double %total.0.lcssa
}

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define double @sum_fast(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #1 {
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
  br i1 %13, label %middle.block, label %vector.body, !llvm.loop !4

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd fast <4 x double> %10, %9       ; [#uses = 1]
  %bin.rdx13 = fadd fast <4 x double> %11, %bin.rdx ; [#uses = 1]
  %bin.rdx14 = fadd fast <4 x double> %12, %bin.rdx13 ; [#uses = 1]
  %14 = tail call fast double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx14) ; [#uses = 2]
  %cmp.n = icmp eq i64 %n.vec, %length_arg        ; [#uses = 1]
  br i1 %cmp.n, label %endfor, label %forbody.preheader15

forbody.preheader15:                              ; preds = %middle.block, %forbody.preheader
  %total.06.ph = phi double [ 0.000000e+00, %forbody.preheader ], [ %14, %middle.block ] ; [#uses = 1, type = double]
  %__key4.05.ph = phi i64 [ 0, %forbody.preheader ], [ %n.vec, %middle.block ] ; [#uses = 1, type = i64]
  br label %forbody

forbody:                                          ; preds = %forbody.preheader15, %forbody
  %total.06 = phi double [ %18, %forbody ], [ %total.06.ph, %forbody.preheader15 ] ; [#uses = 1, type = double]
  %__key4.05 = phi i64 [ %19, %forbody ], [ %__key4.05.ph, %forbody.preheader15 ] ; [#uses = 2, type = i64]
  %15 = getelementptr inbounds float, ptr %source_arg, i64 %__key4.05 ; [#uses = 1, type = ptr]
  %16 = load float, ptr %15, align 4              ; [#uses = 1]
  %17 = fpext float %16 to double                 ; [#uses = 1]
  %18 = fadd fast double %total.06, %17           ; [#uses = 2]
  %19 = add nuw i64 %__key4.05, 1                 ; [#uses = 2]
  %exitcond.not = icmp eq i64 %19, %length_arg    ; [#uses = 1]
  br i1 %exitcond.not, label %endfor, label %forbody, !llvm.loop !7

endfor:                                           ; preds = %forbody, %middle.block, %0
  %total.0.lcssa = phi double [ 0.000000e+00, %0 ], [ %14, %middle.block ], [ %18, %forbody ] ; [#uses = 1, type = double]
  ret double %total.0.lcssa
}

; [#uses = 1]
; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.vector.reduce.fadd.v4f64(double, <4 x double>) #2

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" }
attributes #1 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" "unsafe-fp-math"="true" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.ident = !{!0}

!0 = !{!"ldc version 1.41.0"}
!1 = distinct !{!1, !2}
!2 = !{!"llvm.loop.unroll.disable"}
!3 = distinct !{!3, !2}
!4 = distinct !{!4, !5, !6}
!5 = !{!"llvm.loop.isvectorized", i32 1}
!6 = !{!"llvm.loop.unroll.runtime.disable"}
!7 = distinct !{!7, !6, !5}
