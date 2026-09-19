; ModuleID = '/tmp/d-imagery-e4-fixed-lane8-20260917-180228/lane8.d'
source_filename = "/tmp/d-imagery-e4-fixed-lane8-20260917-180228/lane8.d"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%0 = type { i32, i32, [42 x i8] }

@_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ = global %0 { i32 -2147483644, i32 0, [42 x i8] c"imagery.raster.internal.fixed_lane8_probe\00" } ; [#uses = 1]
@_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ = linkonce_odr hidden global ptr @_D7imagery6raster8internal17fixed_lane8_probe12__ModuleInfoZ, section "__minfo" ; [#uses = 1]
@llvm.used = appending global [1 x ptr] [ptr @_D7imagery6raster8internal17fixed_lane8_probe11__moduleRefZ], section "llvm.metadata" ; [#uses = 0]

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define double @sumFixedLane4(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #0 {
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
  br i1 %prol.iter.cmp.not, label %forbody2.prol.loopexit, label %forbody2.prol, !llvm.loop !1

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
define double @sumFixedLane8(ptr nocapture readonly %source_arg, i64 %length_arg) local_unnamed_addr #0 {
  %1 = icmp ugt i64 %length_arg, 7                ; [#uses = 1]
  br i1 %1, label %forbody, label %endfor

forbody:                                          ; preds = %0, %forbody
  %i.038 = phi i64 [ %45, %forbody ], [ 0, %0 ]   ; [#uses = 9, type = i64]
  %2 = phi <2 x double> [ %43, %forbody ], [ zeroinitializer, %0 ] ; [#uses = 1, type = <2 x double>]
  %3 = phi <2 x double> [ %44, %forbody ], [ zeroinitializer, %0 ] ; [#uses = 1, type = <2 x double>]
  %4 = phi <2 x double> [ %42, %forbody ], [ zeroinitializer, %0 ] ; [#uses = 1, type = <2 x double>]
  %5 = phi <2 x double> [ %41, %forbody ], [ zeroinitializer, %0 ] ; [#uses = 1, type = <2 x double>]
  %6 = getelementptr inbounds float, ptr %source_arg, i64 %i.038 ; [#uses = 1, type = ptr]
  %7 = load float, ptr %6, align 4                ; [#uses = 1]
  %8 = or disjoint i64 %i.038, 1                  ; [#uses = 1]
  %9 = getelementptr inbounds float, ptr %source_arg, i64 %8 ; [#uses = 1, type = ptr]
  %10 = load float, ptr %9, align 4               ; [#uses = 1]
  %11 = or disjoint i64 %i.038, 2                 ; [#uses = 1]
  %12 = getelementptr inbounds float, ptr %source_arg, i64 %11 ; [#uses = 1, type = ptr]
  %13 = load float, ptr %12, align 4              ; [#uses = 1]
  %14 = or disjoint i64 %i.038, 3                 ; [#uses = 1]
  %15 = getelementptr inbounds float, ptr %source_arg, i64 %14 ; [#uses = 1, type = ptr]
  %16 = load float, ptr %15, align 4              ; [#uses = 1]
  %17 = or disjoint i64 %i.038, 4                 ; [#uses = 1]
  %18 = getelementptr inbounds float, ptr %source_arg, i64 %17 ; [#uses = 1, type = ptr]
  %19 = load float, ptr %18, align 4              ; [#uses = 1]
  %20 = or disjoint i64 %i.038, 5                 ; [#uses = 1]
  %21 = getelementptr inbounds float, ptr %source_arg, i64 %20 ; [#uses = 1, type = ptr]
  %22 = load float, ptr %21, align 4              ; [#uses = 1]
  %23 = or disjoint i64 %i.038, 6                 ; [#uses = 1]
  %24 = getelementptr inbounds float, ptr %source_arg, i64 %23 ; [#uses = 1, type = ptr]
  %25 = load float, ptr %24, align 4              ; [#uses = 1]
  %26 = or disjoint i64 %i.038, 7                 ; [#uses = 1]
  %27 = getelementptr inbounds float, ptr %source_arg, i64 %26 ; [#uses = 1, type = ptr]
  %28 = load float, ptr %27, align 4              ; [#uses = 1]
  %29 = insertelement <2 x float> poison, float %19, i64 0 ; [#uses = 1]
  %30 = insertelement <2 x float> %29, float %7, i64 1 ; [#uses = 1]
  %31 = fpext <2 x float> %30 to <2 x double>     ; [#uses = 1]
  %32 = insertelement <2 x float> poison, float %22, i64 0 ; [#uses = 1]
  %33 = insertelement <2 x float> %32, float %10, i64 1 ; [#uses = 1]
  %34 = fpext <2 x float> %33 to <2 x double>     ; [#uses = 1]
  %35 = insertelement <2 x float> poison, float %28, i64 0 ; [#uses = 1]
  %36 = insertelement <2 x float> %35, float %13, i64 1 ; [#uses = 1]
  %37 = fpext <2 x float> %36 to <2 x double>     ; [#uses = 1]
  %38 = insertelement <2 x float> poison, float %25, i64 0 ; [#uses = 1]
  %39 = insertelement <2 x float> %38, float %16, i64 1 ; [#uses = 1]
  %40 = fpext <2 x float> %39 to <2 x double>     ; [#uses = 1]
  %41 = fadd <2 x double> %5, %31                 ; [#uses = 2]
  %42 = fadd <2 x double> %4, %34                 ; [#uses = 2]
  %43 = fadd <2 x double> %2, %40                 ; [#uses = 2]
  %44 = fadd <2 x double> %3, %37                 ; [#uses = 2]
  %45 = add i64 %i.038, 8                         ; [#uses = 3]
  %46 = sub i64 %length_arg, %45                  ; [#uses = 1]
  %47 = icmp ugt i64 %46, 7                       ; [#uses = 1]
  br i1 %47, label %forbody, label %endfor.loopexit

endfor.loopexit:                                  ; preds = %forbody
  %48 = fadd <2 x double> %42, %41                ; [#uses = 1]
  %49 = fadd <2 x double> %43, %44                ; [#uses = 1]
  %50 = fadd <2 x double> %49, %48                ; [#uses = 2]
  %shift = shufflevector <2 x double> %50, <2 x double> poison, <2 x i32> <i32 1, i32 poison> ; [#uses = 1]
  %51 = fadd <2 x double> %50, %shift             ; [#uses = 1]
  %52 = extractelement <2 x double> %51, i64 0    ; [#uses = 1]
  br label %endfor

endfor:                                           ; preds = %endfor.loopexit, %0
  %i.0.lcssa = phi i64 [ 0, %0 ], [ %45, %endfor.loopexit ] ; [#uses = 5, type = i64]
  %53 = phi double [ 0.000000e+00, %0 ], [ %52, %endfor.loopexit ] ; [#uses = 3, type = double]
  %54 = icmp ult i64 %i.0.lcssa, %length_arg      ; [#uses = 1]
  br i1 %54, label %forbody2.preheader, label %endfor4

forbody2.preheader:                               ; preds = %endfor
  %55 = sub i64 %length_arg, %i.0.lcssa           ; [#uses = 1]
  %xtraiter = and i64 %55, 7                      ; [#uses = 2]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0        ; [#uses = 1]
  br i1 %lcmp.mod.not, label %forbody2.prol.loopexit, label %forbody2.prol

forbody2.prol:                                    ; preds = %forbody2.preheader, %forbody2.prol
  %total.054.prol = phi double [ %59, %forbody2.prol ], [ %53, %forbody2.preheader ] ; [#uses = 1, type = double]
  %i.153.prol = phi i64 [ %60, %forbody2.prol ], [ %i.0.lcssa, %forbody2.preheader ] ; [#uses = 2, type = i64]
  %prol.iter = phi i64 [ %prol.iter.next, %forbody2.prol ], [ 0, %forbody2.preheader ] ; [#uses = 1, type = i64]
  %56 = getelementptr inbounds float, ptr %source_arg, i64 %i.153.prol ; [#uses = 1, type = ptr]
  %57 = load float, ptr %56, align 4              ; [#uses = 1]
  %58 = fpext float %57 to double                 ; [#uses = 1]
  %59 = fadd double %total.054.prol, %58          ; [#uses = 3]
  %60 = add nuw i64 %i.153.prol, 1                ; [#uses = 2]
  %prol.iter.next = add i64 %prol.iter, 1         ; [#uses = 2]
  %prol.iter.cmp.not = icmp eq i64 %prol.iter.next, %xtraiter ; [#uses = 1]
  br i1 %prol.iter.cmp.not, label %forbody2.prol.loopexit, label %forbody2.prol, !llvm.loop !3

forbody2.prol.loopexit:                           ; preds = %forbody2.prol, %forbody2.preheader
  %.lcssa.unr = phi double [ poison, %forbody2.preheader ], [ %59, %forbody2.prol ] ; [#uses = 1, type = double]
  %total.054.unr = phi double [ %53, %forbody2.preheader ], [ %59, %forbody2.prol ] ; [#uses = 1, type = double]
  %i.153.unr = phi i64 [ %i.0.lcssa, %forbody2.preheader ], [ %60, %forbody2.prol ] ; [#uses = 1, type = i64]
  %61 = sub i64 %i.0.lcssa, %length_arg           ; [#uses = 1]
  %62 = icmp ugt i64 %61, -8                      ; [#uses = 1]
  br i1 %62, label %endfor4, label %forbody2.preheader.new

forbody2.preheader.new:                           ; preds = %forbody2.prol.loopexit
  %invariant.gep = getelementptr i8, ptr %source_arg, i64 4 ; [#uses = 1, type = ptr]
  %invariant.gep96 = getelementptr i8, ptr %source_arg, i64 8 ; [#uses = 1, type = ptr]
  %invariant.gep98 = getelementptr i8, ptr %source_arg, i64 12 ; [#uses = 1, type = ptr]
  %invariant.gep100 = getelementptr i8, ptr %source_arg, i64 16 ; [#uses = 1, type = ptr]
  %invariant.gep102 = getelementptr i8, ptr %source_arg, i64 20 ; [#uses = 1, type = ptr]
  %invariant.gep104 = getelementptr i8, ptr %source_arg, i64 24 ; [#uses = 1, type = ptr]
  %invariant.gep106 = getelementptr i8, ptr %source_arg, i64 28 ; [#uses = 1, type = ptr]
  br label %forbody2

forbody2:                                         ; preds = %forbody2, %forbody2.preheader.new
  %total.054 = phi double [ %total.054.unr, %forbody2.preheader.new ], [ %87, %forbody2 ] ; [#uses = 1, type = double]
  %i.153 = phi i64 [ %i.153.unr, %forbody2.preheader.new ], [ %88, %forbody2 ] ; [#uses = 9, type = i64]
  %63 = getelementptr inbounds float, ptr %source_arg, i64 %i.153 ; [#uses = 1, type = ptr]
  %64 = load float, ptr %63, align 4              ; [#uses = 1]
  %65 = fpext float %64 to double                 ; [#uses = 1]
  %66 = fadd double %total.054, %65               ; [#uses = 1]
  %gep = getelementptr float, ptr %invariant.gep, i64 %i.153 ; [#uses = 1, type = ptr]
  %67 = load float, ptr %gep, align 4             ; [#uses = 1]
  %68 = fpext float %67 to double                 ; [#uses = 1]
  %69 = fadd double %66, %68                      ; [#uses = 1]
  %gep97 = getelementptr float, ptr %invariant.gep96, i64 %i.153 ; [#uses = 1, type = ptr]
  %70 = load float, ptr %gep97, align 4           ; [#uses = 1]
  %71 = fpext float %70 to double                 ; [#uses = 1]
  %72 = fadd double %69, %71                      ; [#uses = 1]
  %gep99 = getelementptr float, ptr %invariant.gep98, i64 %i.153 ; [#uses = 1, type = ptr]
  %73 = load float, ptr %gep99, align 4           ; [#uses = 1]
  %74 = fpext float %73 to double                 ; [#uses = 1]
  %75 = fadd double %72, %74                      ; [#uses = 1]
  %gep101 = getelementptr float, ptr %invariant.gep100, i64 %i.153 ; [#uses = 1, type = ptr]
  %76 = load float, ptr %gep101, align 4          ; [#uses = 1]
  %77 = fpext float %76 to double                 ; [#uses = 1]
  %78 = fadd double %75, %77                      ; [#uses = 1]
  %gep103 = getelementptr float, ptr %invariant.gep102, i64 %i.153 ; [#uses = 1, type = ptr]
  %79 = load float, ptr %gep103, align 4          ; [#uses = 1]
  %80 = fpext float %79 to double                 ; [#uses = 1]
  %81 = fadd double %78, %80                      ; [#uses = 1]
  %gep105 = getelementptr float, ptr %invariant.gep104, i64 %i.153 ; [#uses = 1, type = ptr]
  %82 = load float, ptr %gep105, align 4          ; [#uses = 1]
  %83 = fpext float %82 to double                 ; [#uses = 1]
  %84 = fadd double %81, %83                      ; [#uses = 1]
  %gep107 = getelementptr float, ptr %invariant.gep106, i64 %i.153 ; [#uses = 1, type = ptr]
  %85 = load float, ptr %gep107, align 4          ; [#uses = 1]
  %86 = fpext float %85 to double                 ; [#uses = 1]
  %87 = fadd double %84, %86                      ; [#uses = 2]
  %88 = add nuw i64 %i.153, 8                     ; [#uses = 2]
  %exitcond.not.7 = icmp eq i64 %88, %length_arg  ; [#uses = 1]
  br i1 %exitcond.not.7, label %endfor4, label %forbody2

endfor4:                                          ; preds = %forbody2.prol.loopexit, %forbody2, %endfor
  %total.0.lcssa = phi double [ %53, %endfor ], [ %.lcssa.unr, %forbody2.prol.loopexit ], [ %87, %forbody2 ] ; [#uses = 1, type = double]
  ret double %total.0.lcssa
}

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "frame-pointer"="none" "target-cpu"="skylake" "target-features"="+prfchw,-cldemote,+avx,+aes,+sahf,+pclmul,-xop,+crc32,+xsaves,-avx512fp16,-usermsr,-sm4,-egpr,+sse4.1,-avx512ifma,+xsave,+sse4.2,-tsxldtrk,-sm3,-ptwrite,-widekl,+invpcid,+64bit,+xsavec,-avx10.1-512,-avx512vpopcntdq,+cmov,-avx512vp2intersect,-avx512cd,+movbe,-avxvnniint8,-ccmp,-amx-int8,-kl,-avx10.1-256,-sha512,-avxvnni,-rtm,+adx,+avx2,-hreset,-movdiri,-serialize,-vpclmulqdq,-avx512vl,-uintr,-cf,+clflushopt,-raoint,-cmpccxadd,+bmi,-amx-tile,+sse,-gfni,-avxvnniint16,-amx-fp16,-ndd,+xsaveopt,+rdrnd,-avx512f,-amx-bf16,-avx512bf16,-avx512vnni,-push2pop2,+cx8,-avx512bw,+sse3,-pku,+fsgsbase,-clzero,-mwaitx,-lwp,+lzcnt,-sha,-movdir64b,-ppx,-wbnoinvd,-enqcmd,-avxneconvert,-tbm,-pconfig,-amx-complex,+ssse3,+cx16,+bmi2,+fma,+popcnt,-avxifma,+f16c,-avx512bitalg,-rdpru,-clwb,+mmx,+sse2,+rdseed,-avx512vbmi2,-prefetchi,-rdpid,-fma4,-avx512vbmi,-shstk,-vaes,-waitpkg,+sgx,+fxsr,-avx512dq,-sse4a" }

!llvm.ident = !{!0}

!0 = !{!"ldc version 1.41.0"}
!1 = distinct !{!1, !2}
!2 = !{!"llvm.loop.unroll.disable"}
!3 = distinct !{!3, !2}
