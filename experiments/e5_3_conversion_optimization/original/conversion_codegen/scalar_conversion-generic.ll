; ModuleID = 'source/imagery/raster/internal/scalar_conversion.d'
source_filename = "source/imagery/raster/internal/scalar_conversion.d"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%0 = type { i32, i32, [42 x i8] }
%"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" = type { [1 x i64], ptr }
%"mir.ndslice.slice.Slice!(float*, 1LU, mir_slice_kind.contiguous).mir_slice" = type { [1 x i64], ptr }
%"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" = type { [1 x i64], ptr }
%"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" = type { [1 x i64], ptr }
%"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" = type { [1 x i64], ptr }

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T6lengthVmi0ZQmMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T6lengthVmi0ZQmMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T13opIndexAssignZQqMFNaNbNcNiNjNlNefG1mXf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7opIndexZQjMFNaNbNcNiNjNlNeG1mXxh = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZxh = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZyh = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7toConstZQjMxFNaNbNiNjNlNeZSQDzQDyQDt__TQDqTPxhVmi1VQDji2ZQEi = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv16indexStrideValueMxFNaNbNiNlNflZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv10accessFlatMFNaNbNcNiNjNlNemZf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv11__xopEqualsMxFKxSQDmQDlQDg__TQDdTQCwVmi1VQCxi2ZQDvZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZxf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZyf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7toConstZQjMxFNaNbNiNjNlNeZSQDzQDyQDt__TQDqTPxfVmi1VQDji2ZQEi = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T7toConstZQjMxFNaNbNiNjNlNeZSQDyQDxQDs__TQDpTPxfVmi1VQDji2ZQEh = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T11indexStrideVmi1ZQsMxFNaNbNiNlNfG1mZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T13opIndexAssignZQqMFNcNjNlNefG1mX3funFNaNbNcNiNfKfKfZf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T11indexStrideVmi1ZQsMxFNaNbNiNlNfG1mZm = comdat any

$_D4core8lifetime__T7forwardS_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T13opIndexAssignZQqMFNcNjNlNefG1mX5valuefZ__T3fwdS_DQEvQEuQEp__TQEmTQEfVmi1VQEgi2ZQFe__TQDjZQDnMFNcNjNlNefQCyXQCyfZQCsMFNaNbNdNiNfZf = comdat any

$_D4core8lifetime__T4moveTfZQiFNaNbNiNfNkMKfZf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl = comdat any

$_D4core8lifetime__T8moveImplTfZQmFNaNbNiNfNkMKfZf = comdat any

$_D4core8lifetime__T15trustedMoveImplTfZQuFNaNbNiNeNkMKfZf = comdat any

$_D4core8lifetime__T15moveEmplaceImplTfZQuFNaNbNiNfMKfNkMKfZv = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l = comdat any

$_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPxhVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo = comdat any

$_D3mir10primitives__T13anyEmptyShapeVmi1ZQuFNaNbNdNiNfMxG1mZb = comdat any

$_D3mir9qualifier__T10lightScopeTPxhZQrFNaNbNdNiNfNkQtZQw = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m = comdat any

$_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPxhVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb = comdat any

$_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa158_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQMna293_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBLf7ndslice5slice__T9mir_sliceTPxhVmi1VEQBMuQBpQBk14mir_slice_kindi2ZQBxTQCxZQBNeFNaNbNiNfQDoQDrZv = comdat any

$_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPxhVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm = comdat any

$_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTxhTxhZQBrFNaNbNiNfKxhKxhZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZxh = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l = comdat any

$_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPyhVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl = comdat any

$_D3mir9qualifier__T10lightScopeTPyhZQrFNaNbNdNiNfNkQtZQw = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m = comdat any

$_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPyhVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb = comdat any

$_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa166_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQNda309_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBNb7ndslice5slice__T9mir_sliceTPyhVmi1VEQBOqQBpQBk14mir_slice_kindi2ZQBxTQCxZQBPaFNaNbNiNfQDoQDrZv = comdat any

$_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPyhVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm = comdat any

$_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTyhTyhZQBrFNaNbNiNfKyhKyhZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZyh = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T12elementCountZQpMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8anyEmptyZQkMxFNaNbNdNiNlNeZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T7stridesZQjMxFNaNbNdNiNlNeZG1l = comdat any

$_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPxfVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEeQEdQDy__TQDvTPxfVmi1VQDpi2ZQEn = comdat any

$_D3mir9qualifier__T10lightScopeTPxfZQrFNaNbNdNiNfNkQtZQw = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m = comdat any

$_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPxfVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb = comdat any

$_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa158_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQMna293_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBLf7ndslice5slice__T9mir_sliceTPxfVmi1VEQBMuQBpQBk14mir_slice_kindi2ZQBxTQCxZQBNeFNaNbNiNfQDoQDrZv = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb = comdat any

$_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPxfVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm = comdat any

$_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTxfTxfZQBrFNaNbNiNfKxfKxfZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZxf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l = comdat any

$_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPyfVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl = comdat any

$_D3mir9qualifier__T10lightScopeTPyfZQrFNaNbNdNiNfNkQtZQw = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m = comdat any

$_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPyfVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb = comdat any

$_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa166_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQNda309_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBNb7ndslice5slice__T9mir_sliceTPyfVmi1VEQBOqQBpQBk14mir_slice_kindi2ZQBxTQCxZQBPaFNaNbNiNfQDoQDrZv = comdat any

$_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPyfVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm = comdat any

$_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTyfTyfZQBrFNaNbNiNfKyfKyfZb = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZyf = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv = comdat any

$_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb = comdat any

$_D6object__T10RTInfoImplVAmA2i16i2ZQxyG2m = comdat any

@_D6object__T10RTInfoImplVAmA2i16i2ZQxyG2m = weak_odr local_unnamed_addr constant [2 x i64] [i64 16, i64 2], comdat, align 8 ; [#uses = 0]
@_D7imagery6raster8internal17scalar_conversion12__ModuleInfoZ = global %0 { i32 -2147483644, i32 0, [42 x i8] c"imagery.raster.internal.scalar_conversion\00" } ; [#uses = 1]
@_D7imagery6raster8internal17scalar_conversion11__moduleRefZ = linkonce_odr hidden global ptr @_D7imagery6raster8internal17scalar_conversion12__ModuleInfoZ, section "__minfo" ; [#uses = 1]
@llvm.used = appending global [1 x ptr] [ptr @_D7imagery6raster8internal17scalar_conversion11__moduleRefZ], section "llvm.metadata" ; [#uses = 0]

; [#uses = 0]
; Function Attrs: nofree norecurse nosync nounwind memory(readwrite, inaccessiblemem: none) uwtable
define zeroext i1 @_D7imagery6raster8internal17scalar_conversion37scalarConvertUbyteToFloatContiguous1DFNaNbNiNfMS3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBwMSQCwQCvQCq__TQCnTPfVmi1VQCfi2ZQDeZb(%"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %source_arg, %"mir.ndslice.slice.Slice!(float*, 1LU, mir_slice_kind.contiguous).mir_slice" %target_arg) local_unnamed_addr #0 {
  %source_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %source_arg, 0, 0 ; [#uses = 10]
  %source_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %source_arg, 1 ; [#uses = 8]
  %target_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(float*, 1LU, mir_slice_kind.contiguous).mir_slice" %target_arg, 0, 0 ; [#uses = 1]
  %target_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(float*, 1LU, mir_slice_kind.contiguous).mir_slice" %target_arg, 1 ; [#uses = 8]
  %.not = icmp eq i64 %source_arg.fca.0.0.extract, %target_arg.fca.0.0.extract ; [#uses = 2]
  %1 = icmp ne i64 %source_arg.fca.0.0.extract, 0 ; [#uses = 1]
  %or.cond = and i1 %.not, %1                     ; [#uses = 1]
  br i1 %or.cond, label %forbody.preheader, label %common.ret

forbody.preheader:                                ; preds = %0
  %min.iters.check = icmp ult i64 %source_arg.fca.0.0.extract, 8 ; [#uses = 1]
  br i1 %min.iters.check, label %forbody.preheader11, label %vector.memcheck

forbody.preheader11:                              ; preds = %middle.block, %vector.memcheck, %forbody.preheader
  %__key28.08.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %forbody.preheader ], [ %n.vec, %middle.block ] ; [#uses = 3, type = i64]
  %xtraiter = and i64 %source_arg.fca.0.0.extract, 3 ; [#uses = 2]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0        ; [#uses = 1]
  br i1 %lcmp.mod.not, label %forbody.prol.loopexit, label %forbody.prol

forbody.prol:                                     ; preds = %forbody.preheader11, %forbody.prol
  %__key28.08.prol = phi i64 [ %6, %forbody.prol ], [ %__key28.08.ph, %forbody.preheader11 ] ; [#uses = 3, type = i64]
  %prol.iter = phi i64 [ %prol.iter.next, %forbody.prol ], [ 0, %forbody.preheader11 ] ; [#uses = 1, type = i64]
  %2 = getelementptr inbounds i8, ptr %source_arg.fca.1.extract, i64 %__key28.08.prol ; [#uses = 1, type = ptr]
  %3 = load i8, ptr %2, align 1                   ; [#uses = 1]
  %4 = uitofp i8 %3 to float                      ; [#uses = 1]
  %5 = getelementptr inbounds float, ptr %target_arg.fca.1.extract, i64 %__key28.08.prol ; [#uses = 1, type = ptr]
  store float %4, ptr %5, align 4
  %6 = add nuw i64 %__key28.08.prol, 1            ; [#uses = 2]
  %prol.iter.next = add i64 %prol.iter, 1         ; [#uses = 2]
  %prol.iter.cmp.not = icmp eq i64 %prol.iter.next, %xtraiter ; [#uses = 1]
  br i1 %prol.iter.cmp.not, label %forbody.prol.loopexit, label %forbody.prol, !llvm.loop !1

forbody.prol.loopexit:                            ; preds = %forbody.prol, %forbody.preheader11
  %__key28.08.unr = phi i64 [ %__key28.08.ph, %forbody.preheader11 ], [ %6, %forbody.prol ] ; [#uses = 1, type = i64]
  %7 = sub i64 %__key28.08.ph, %source_arg.fca.0.0.extract ; [#uses = 1]
  %8 = icmp ugt i64 %7, -4                        ; [#uses = 1]
  br i1 %8, label %common.ret, label %forbody

vector.memcheck:                                  ; preds = %forbody.preheader
  %9 = shl i64 %source_arg.fca.0.0.extract, 2     ; [#uses = 1]
  %scevgep = getelementptr i8, ptr %target_arg.fca.1.extract, i64 %9 ; [#uses = 1, type = ptr]
  %scevgep9 = getelementptr i8, ptr %source_arg.fca.1.extract, i64 %source_arg.fca.0.0.extract ; [#uses = 1, type = ptr]
  %bound0 = icmp ult ptr %target_arg.fca.1.extract, %scevgep9 ; [#uses = 1]
  %bound1 = icmp ult ptr %source_arg.fca.1.extract, %scevgep ; [#uses = 1]
  %found.conflict = and i1 %bound0, %bound1       ; [#uses = 1]
  br i1 %found.conflict, label %forbody.preheader11, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %source_arg.fca.0.0.extract, -8 ; [#uses = 3]
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ] ; [#uses = 3, type = i64]
  %10 = getelementptr inbounds i8, ptr %source_arg.fca.1.extract, i64 %index ; [#uses = 2, type = ptr]
  %11 = getelementptr inbounds i8, ptr %10, i64 4 ; [#uses = 1, type = ptr]
  %wide.load = load <4 x i8>, ptr %10, align 1, !alias.scope !3 ; [#uses = 1]
  %wide.load10 = load <4 x i8>, ptr %11, align 1, !alias.scope !3 ; [#uses = 1]
  %12 = uitofp <4 x i8> %wide.load to <4 x float> ; [#uses = 1]
  %13 = uitofp <4 x i8> %wide.load10 to <4 x float> ; [#uses = 1]
  %14 = getelementptr inbounds float, ptr %target_arg.fca.1.extract, i64 %index ; [#uses = 2, type = ptr]
  %15 = getelementptr inbounds i8, ptr %14, i64 16 ; [#uses = 1, type = ptr]
  store <4 x float> %12, ptr %14, align 4, !alias.scope !6, !noalias !3
  store <4 x float> %13, ptr %15, align 4, !alias.scope !6, !noalias !3
  %index.next = add nuw i64 %index, 8             ; [#uses = 2]
  %16 = icmp eq i64 %index.next, %n.vec           ; [#uses = 1]
  br i1 %16, label %middle.block, label %vector.body, !llvm.loop !8

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %source_arg.fca.0.0.extract, %n.vec ; [#uses = 1]
  br i1 %cmp.n, label %common.ret, label %forbody.preheader11

common.ret:                                       ; preds = %forbody.prol.loopexit, %forbody, %middle.block, %0
  ret i1 %.not

forbody:                                          ; preds = %forbody.prol.loopexit, %forbody
  %__key28.08 = phi i64 [ %36, %forbody ], [ %__key28.08.unr, %forbody.prol.loopexit ] ; [#uses = 6, type = i64]
  %17 = getelementptr inbounds i8, ptr %source_arg.fca.1.extract, i64 %__key28.08 ; [#uses = 1, type = ptr]
  %18 = load i8, ptr %17, align 1                 ; [#uses = 1]
  %19 = uitofp i8 %18 to float                    ; [#uses = 1]
  %20 = getelementptr inbounds float, ptr %target_arg.fca.1.extract, i64 %__key28.08 ; [#uses = 1, type = ptr]
  store float %19, ptr %20, align 4
  %21 = add nuw i64 %__key28.08, 1                ; [#uses = 2]
  %22 = getelementptr inbounds i8, ptr %source_arg.fca.1.extract, i64 %21 ; [#uses = 1, type = ptr]
  %23 = load i8, ptr %22, align 1                 ; [#uses = 1]
  %24 = uitofp i8 %23 to float                    ; [#uses = 1]
  %25 = getelementptr inbounds float, ptr %target_arg.fca.1.extract, i64 %21 ; [#uses = 1, type = ptr]
  store float %24, ptr %25, align 4
  %26 = add nuw i64 %__key28.08, 2                ; [#uses = 2]
  %27 = getelementptr inbounds i8, ptr %source_arg.fca.1.extract, i64 %26 ; [#uses = 1, type = ptr]
  %28 = load i8, ptr %27, align 1                 ; [#uses = 1]
  %29 = uitofp i8 %28 to float                    ; [#uses = 1]
  %30 = getelementptr inbounds float, ptr %target_arg.fca.1.extract, i64 %26 ; [#uses = 1, type = ptr]
  store float %29, ptr %30, align 4
  %31 = add nuw i64 %__key28.08, 3                ; [#uses = 2]
  %32 = getelementptr inbounds i8, ptr %source_arg.fca.1.extract, i64 %31 ; [#uses = 1, type = ptr]
  %33 = load i8, ptr %32, align 1                 ; [#uses = 1]
  %34 = uitofp i8 %33 to float                    ; [#uses = 1]
  %35 = getelementptr inbounds float, ptr %target_arg.fca.1.extract, i64 %31 ; [#uses = 1, type = ptr]
  store float %34, ptr %35, align 4
  %36 = add nuw i64 %__key28.08, 4                ; [#uses = 2]
  %exitcond.not.3 = icmp eq i64 %36, %source_arg.fca.0.0.extract ; [#uses = 1]
  br i1 %exitcond.not.3, label %common.ret, label %forbody, !llvm.loop !11
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T6lengthVmi0ZQmMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T6lengthVmi0ZQmMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T13opIndexAssignZQqMFNaNbNcNiNjNlNefG1mXf(ptr nonnull %.this_arg, float %value_arg, [1 x i64] %_indices_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %_indices_arg.fca.0.extract.i = extractvalue [1 x i64] %_indices_arg, 0 ; [#uses = 1]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds float, ptr %2, i64 %_indices_arg.fca.0.extract.i ; [#uses = 2, type = ptr]
  store float %value_arg, ptr %3, align 4
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7opIndexZQjMFNaNbNcNiNjNlNeG1mXxh(ptr nonnull %.this_arg, [1 x i64] %_indices_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %_indices_arg.fca.0.extract.i = extractvalue [1 x i64] %_indices_arg, 0 ; [#uses = 1]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds i8, ptr %2, i64 %_indices_arg.fca.0.extract.i ; [#uses = 1, type = ptr]
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl(ptr nonnull %.this_arg, i64 %n_arg) local_unnamed_addr #1 comdat {
  ret i64 %n_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZxh(ptr nonnull %.this_arg, i64 %index_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds i8, ptr %2, i64 %index_arg ; [#uses = 1, type = ptr]
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %p) local_unnamed_addr #1 comdat {
  %bcmp.i = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %p, i64 8) ; [#uses = 1]
  %.not.i = icmp eq i32 %bcmp.i, 0                ; [#uses = 1]
  br i1 %.not.i, label %endif.i, label %_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

endif.i:                                          ; preds = %0
  %.unpack.i.i = load i64, ptr %.this_arg, align 8 ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i.i, 0                ; [#uses = 1]
  br i1 %1, label %_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %endif2.i

endif2.i:                                         ; preds = %endif.i
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %p, i64 8   ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %label.L.i

label.L.i:                                        ; preds = %endif2.i
  %ret.sroa.0.0.copyload.i23.i = load i64, ptr %p, align 1 ; [#uses = 1]
  %.not.i.i = icmp eq i64 %ret.sroa.0.0.copyload.i23.i, %.unpack.i.i ; [#uses = 1]
  br i1 %.not.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

dowhile.i.i.i.i:                                  ; preds = %label.L.i, %dowhile.i.i.i.i
  %__param_0.sroa.4.0.i.i.i.i = phi ptr [ %12, %dowhile.i.i.i.i ], [ %4, %label.L.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i.i = phi i64 [ %11, %dowhile.i.i.i.i ], [ %.unpack.i.i, %label.L.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i.i = phi ptr [ %10, %dowhile.i.i.i.i ], [ %5, %label.L.i ] ; [#uses = 2, type = ptr]
  %7 = load i8, ptr %__param_0.sroa.4.0.i.i.i.i, align 1 ; [#uses = 1]
  %8 = load i8, ptr %__param_1.sroa.3.0.i.i.i.i, align 1 ; [#uses = 1]
  %9 = icmp eq i8 %7, %8                          ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i.i, -1   ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit: ; preds = %dowhile.i.i.i.i, %0, %endif.i, %endif2.i, %label.L.i
  %common.ret.op.i = phi i1 [ false, %0 ], [ true, %endif.i ], [ false, %label.L.i ], [ true, %endif2.i ], [ %9, %dowhile.i.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op.i
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %rslice) local_unnamed_addr #1 comdat {
  %bcmp = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %rslice, i64 8) ; [#uses = 1]
  %.not = icmp eq i32 %bcmp, 0                    ; [#uses = 1]
  br i1 %.not, label %endif, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i.i, %endif2, %label.L, %endif, %0
  %common.ret.op = phi i1 [ false, %0 ], [ true, %endif ], [ false, %label.L ], [ true, %endif2 ], [ %9, %dowhile.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

endif:                                            ; preds = %0
  %.unpack.i = load i64, ptr %.this_arg, align 8  ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i, 0                  ; [#uses = 1]
  br i1 %1, label %common.ret, label %endif2

endif2:                                           ; preds = %endif
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %rslice, i64 8 ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %common.ret, label %label.L

label.L:                                          ; preds = %endif2
  %ret.sroa.0.0.copyload.i23 = load i64, ptr %rslice, align 1 ; [#uses = 1]
  %.not.i = icmp eq i64 %ret.sroa.0.0.copyload.i23, %.unpack.i ; [#uses = 1]
  br i1 %.not.i, label %dowhile.i.i.i, label %common.ret

dowhile.i.i.i:                                    ; preds = %label.L, %dowhile.i.i.i
  %__param_0.sroa.4.0.i.i.i = phi ptr [ %12, %dowhile.i.i.i ], [ %4, %label.L ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i = phi i64 [ %11, %dowhile.i.i.i ], [ %.unpack.i, %label.L ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i = phi ptr [ %10, %dowhile.i.i.i ], [ %5, %label.L ] ; [#uses = 2, type = ptr]
  %7 = load i8, ptr %__param_0.sroa.4.0.i.i.i, align 1 ; [#uses = 1]
  %8 = load i8, ptr %__param_1.sroa.3.0.i.i.i, align 1 ; [#uses = 1]
  %9 = icmp eq i8 %7, %8                          ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i, -1     ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i, label %dowhile.i.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl(ptr nonnull %.this_arg, i64 %n_arg) local_unnamed_addr #1 comdat {
  ret i64 %n_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZyh(ptr nonnull %.this_arg, i64 %index_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds i8, ptr %2, i64 %index_arg ; [#uses = 1, type = ptr]
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %p) local_unnamed_addr #1 comdat {
  %bcmp.i = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %p, i64 8) ; [#uses = 1]
  %.not.i = icmp eq i32 %bcmp.i, 0                ; [#uses = 1]
  br i1 %.not.i, label %endif.i, label %_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

endif.i:                                          ; preds = %0
  %.unpack.i.i = load i64, ptr %.this_arg, align 8 ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i.i, 0                ; [#uses = 1]
  br i1 %1, label %_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %endif2.i

endif2.i:                                         ; preds = %endif.i
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %p, i64 8   ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %label.L.i

label.L.i:                                        ; preds = %endif2.i
  %ret.sroa.0.0.copyload.i23.i = load i64, ptr %p, align 1 ; [#uses = 1]
  %.not.i.i = icmp eq i64 %ret.sroa.0.0.copyload.i23.i, %.unpack.i.i ; [#uses = 1]
  br i1 %.not.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

dowhile.i.i.i.i:                                  ; preds = %label.L.i, %dowhile.i.i.i.i
  %__param_0.sroa.4.0.i.i.i.i = phi ptr [ %12, %dowhile.i.i.i.i ], [ %4, %label.L.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i.i = phi i64 [ %11, %dowhile.i.i.i.i ], [ %.unpack.i.i, %label.L.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i.i = phi ptr [ %10, %dowhile.i.i.i.i ], [ %5, %label.L.i ] ; [#uses = 2, type = ptr]
  %7 = load i8, ptr %__param_0.sroa.4.0.i.i.i.i, align 1 ; [#uses = 1]
  %8 = load i8, ptr %__param_1.sroa.3.0.i.i.i.i, align 1 ; [#uses = 1]
  %9 = icmp eq i8 %7, %8                          ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i.i, -1   ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit: ; preds = %dowhile.i.i.i.i, %0, %endif.i, %endif2.i, %label.L.i
  %common.ret.op.i = phi i1 [ false, %0 ], [ true, %endif.i ], [ false, %label.L.i ], [ true, %endif2.i ], [ %9, %dowhile.i.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op.i
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %rslice) local_unnamed_addr #1 comdat {
  %bcmp = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %rslice, i64 8) ; [#uses = 1]
  %.not = icmp eq i32 %bcmp, 0                    ; [#uses = 1]
  br i1 %.not, label %endif, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i.i, %endif2, %label.L, %endif, %0
  %common.ret.op = phi i1 [ false, %0 ], [ true, %endif ], [ false, %label.L ], [ true, %endif2 ], [ %9, %dowhile.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

endif:                                            ; preds = %0
  %.unpack.i = load i64, ptr %.this_arg, align 8  ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i, 0                  ; [#uses = 1]
  br i1 %1, label %common.ret, label %endif2

endif2:                                           ; preds = %endif
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %rslice, i64 8 ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %common.ret, label %label.L

label.L:                                          ; preds = %endif2
  %ret.sroa.0.0.copyload.i23 = load i64, ptr %rslice, align 1 ; [#uses = 1]
  %.not.i = icmp eq i64 %ret.sroa.0.0.copyload.i23, %.unpack.i ; [#uses = 1]
  br i1 %.not.i, label %dowhile.i.i.i, label %common.ret

dowhile.i.i.i:                                    ; preds = %label.L, %dowhile.i.i.i
  %__param_0.sroa.4.0.i.i.i = phi ptr [ %12, %dowhile.i.i.i ], [ %4, %label.L ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i = phi i64 [ %11, %dowhile.i.i.i ], [ %.unpack.i, %label.L ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i = phi ptr [ %10, %dowhile.i.i.i ], [ %5, %label.L ] ; [#uses = 2, type = ptr]
  %7 = load i8, ptr %__param_0.sroa.4.0.i.i.i, align 1 ; [#uses = 1]
  %8 = load i8, ptr %__param_1.sroa.3.0.i.i.i, align 1 ; [#uses = 1]
  %9 = icmp eq i8 %7, %8                          ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i, -1     ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i, i64 1 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i, label %dowhile.i.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: alwaysinline uwtable
define weak_odr %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7toConstZQjMxFNaNbNiNjNlNeZSQDzQDyQDt__TQDqTPxhVmi1VQDji2ZQEi(ptr nonnull %.this_arg) local_unnamed_addr #2 comdat {
  %.structliteral.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %.structliteral.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv16indexStrideValueMxFNaNbNiNlNflZl(ptr nonnull %.this_arg, i64 %n_arg) local_unnamed_addr #1 comdat {
  ret i64 %n_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv10accessFlatMFNaNbNcNiNjNlNemZf(ptr nonnull %.this_arg, i64 %index_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds float, ptr %2, i64 %index_arg ; [#uses = 1, type = ptr]
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv11__xopEqualsMxFKxSQDmQDlQDg__TQDdTQCwVmi1VQCxi2ZQDvZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %p) local_unnamed_addr #1 comdat {
  %bcmp.i = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %p, i64 8) ; [#uses = 1]
  %.not.i = icmp eq i32 %bcmp.i, 0                ; [#uses = 1]
  br i1 %.not.i, label %endif.i, label %_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb.exit

endif.i:                                          ; preds = %0
  %.unpack.i.i = load i64, ptr %.this_arg, align 8 ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i.i, 0                ; [#uses = 1]
  br i1 %1, label %_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb.exit, label %endif2.i

endif2.i:                                         ; preds = %endif.i
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %p, i64 8   ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb.exit, label %label.L.i

label.L.i:                                        ; preds = %endif2.i
  %ret.sroa.0.0.copyload.i23.i = load i64, ptr %p, align 1 ; [#uses = 1]
  %.not.i.i = icmp eq i64 %ret.sroa.0.0.copyload.i23.i, %.unpack.i.i ; [#uses = 1]
  br i1 %.not.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb.exit

dowhile.i.i.i.i:                                  ; preds = %label.L.i, %dowhile.i.i.i.i
  %__param_0.sroa.4.0.i.i.i.i = phi ptr [ %12, %dowhile.i.i.i.i ], [ %4, %label.L.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i.i = phi i64 [ %11, %dowhile.i.i.i.i ], [ %.unpack.i.i, %label.L.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i.i = phi ptr [ %10, %dowhile.i.i.i.i ], [ %5, %label.L.i ] ; [#uses = 2, type = ptr]
  %7 = load float, ptr %__param_0.sroa.4.0.i.i.i.i, align 4 ; [#uses = 1]
  %8 = load float, ptr %__param_1.sroa.3.0.i.i.i.i, align 4 ; [#uses = 1]
  %9 = fcmp fast oeq float %7, %8                 ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i.i, -1   ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb.exit

_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb.exit: ; preds = %dowhile.i.i.i.i, %0, %endif.i, %endif2.i, %label.L.i
  %common.ret.op.i = phi i1 [ false, %0 ], [ true, %endif.i ], [ false, %label.L.i ], [ true, %endif2.i ], [ %9, %dowhile.i.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op.i
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8opEqualsTQCaVQBxi2ZQuMxFNaNbNiNlNeKxSQEiQEhQEc__TQDzTQDsVmi1VQDti2ZQErZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %rslice) local_unnamed_addr #1 comdat {
  %bcmp = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %rslice, i64 8) ; [#uses = 1]
  %.not = icmp eq i32 %bcmp, 0                    ; [#uses = 1]
  br i1 %.not, label %endif, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i.i, %endif2, %label.L, %endif, %0
  %common.ret.op = phi i1 [ false, %0 ], [ true, %endif ], [ false, %label.L ], [ true, %endif2 ], [ %9, %dowhile.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

endif:                                            ; preds = %0
  %.unpack.i = load i64, ptr %.this_arg, align 8  ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i, 0                  ; [#uses = 1]
  br i1 %1, label %common.ret, label %endif2

endif2:                                           ; preds = %endif
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %rslice, i64 8 ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %common.ret, label %label.L

label.L:                                          ; preds = %endif2
  %ret.sroa.0.0.copyload.i23 = load i64, ptr %rslice, align 1 ; [#uses = 1]
  %.not.i = icmp eq i64 %ret.sroa.0.0.copyload.i23, %.unpack.i ; [#uses = 1]
  br i1 %.not.i, label %dowhile.i.i.i, label %common.ret

dowhile.i.i.i:                                    ; preds = %label.L, %dowhile.i.i.i
  %__param_0.sroa.4.0.i.i.i = phi ptr [ %12, %dowhile.i.i.i ], [ %4, %label.L ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i = phi i64 [ %11, %dowhile.i.i.i ], [ %.unpack.i, %label.L ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i = phi ptr [ %10, %dowhile.i.i.i ], [ %5, %label.L ] ; [#uses = 2, type = ptr]
  %7 = load float, ptr %__param_0.sroa.4.0.i.i.i, align 4 ; [#uses = 1]
  %8 = load float, ptr %__param_1.sroa.3.0.i.i.i, align 4 ; [#uses = 1]
  %9 = fcmp fast oeq float %7, %8                 ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i, -1     ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i, label %dowhile.i.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl(ptr nonnull %.this_arg, i64 %n_arg) local_unnamed_addr #1 comdat {
  ret i64 %n_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZxf(ptr nonnull %.this_arg, i64 %index_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds float, ptr %2, i64 %index_arg ; [#uses = 1, type = ptr]
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %p) local_unnamed_addr #1 comdat {
  %bcmp.i = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %p, i64 8) ; [#uses = 1]
  %.not.i = icmp eq i32 %bcmp.i, 0                ; [#uses = 1]
  br i1 %.not.i, label %endif.i, label %_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

endif.i:                                          ; preds = %0
  %.unpack.i.i = load i64, ptr %.this_arg, align 8 ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i.i, 0                ; [#uses = 1]
  br i1 %1, label %_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %endif2.i

endif2.i:                                         ; preds = %endif.i
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %p, i64 8   ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %label.L.i

label.L.i:                                        ; preds = %endif2.i
  %ret.sroa.0.0.copyload.i23.i = load i64, ptr %p, align 1 ; [#uses = 1]
  %.not.i.i = icmp eq i64 %ret.sroa.0.0.copyload.i23.i, %.unpack.i.i ; [#uses = 1]
  br i1 %.not.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

dowhile.i.i.i.i:                                  ; preds = %label.L.i, %dowhile.i.i.i.i
  %__param_0.sroa.4.0.i.i.i.i = phi ptr [ %12, %dowhile.i.i.i.i ], [ %4, %label.L.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i.i = phi i64 [ %11, %dowhile.i.i.i.i ], [ %.unpack.i.i, %label.L.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i.i = phi ptr [ %10, %dowhile.i.i.i.i ], [ %5, %label.L.i ] ; [#uses = 2, type = ptr]
  %7 = load float, ptr %__param_0.sroa.4.0.i.i.i.i, align 4 ; [#uses = 1]
  %8 = load float, ptr %__param_1.sroa.3.0.i.i.i.i, align 4 ; [#uses = 1]
  %9 = fcmp fast oeq float %7, %8                 ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i.i, -1   ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit: ; preds = %dowhile.i.i.i.i, %0, %endif.i, %endif2.i, %label.L.i
  %common.ret.op.i = phi i1 [ false, %0 ], [ true, %endif.i ], [ false, %label.L.i ], [ true, %endif2.i ], [ %9, %dowhile.i.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op.i
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %rslice) local_unnamed_addr #1 comdat {
  %bcmp = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %rslice, i64 8) ; [#uses = 1]
  %.not = icmp eq i32 %bcmp, 0                    ; [#uses = 1]
  br i1 %.not, label %endif, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i.i, %endif2, %label.L, %endif, %0
  %common.ret.op = phi i1 [ false, %0 ], [ true, %endif ], [ false, %label.L ], [ true, %endif2 ], [ %9, %dowhile.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

endif:                                            ; preds = %0
  %.unpack.i = load i64, ptr %.this_arg, align 8  ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i, 0                  ; [#uses = 1]
  br i1 %1, label %common.ret, label %endif2

endif2:                                           ; preds = %endif
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %rslice, i64 8 ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %common.ret, label %label.L

label.L:                                          ; preds = %endif2
  %ret.sroa.0.0.copyload.i23 = load i64, ptr %rslice, align 1 ; [#uses = 1]
  %.not.i = icmp eq i64 %ret.sroa.0.0.copyload.i23, %.unpack.i ; [#uses = 1]
  br i1 %.not.i, label %dowhile.i.i.i, label %common.ret

dowhile.i.i.i:                                    ; preds = %label.L, %dowhile.i.i.i
  %__param_0.sroa.4.0.i.i.i = phi ptr [ %12, %dowhile.i.i.i ], [ %4, %label.L ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i = phi i64 [ %11, %dowhile.i.i.i ], [ %.unpack.i, %label.L ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i = phi ptr [ %10, %dowhile.i.i.i ], [ %5, %label.L ] ; [#uses = 2, type = ptr]
  %7 = load float, ptr %__param_0.sroa.4.0.i.i.i, align 4 ; [#uses = 1]
  %8 = load float, ptr %__param_1.sroa.3.0.i.i.i, align 4 ; [#uses = 1]
  %9 = fcmp fast oeq float %7, %8                 ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i, -1     ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i, label %dowhile.i.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw16indexStrideValueMxFNaNbNiNlNflZl(ptr nonnull %.this_arg, i64 %n_arg) local_unnamed_addr #1 comdat {
  ret i64 %n_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw10accessFlatMFNaNbNcNiNjNlNemZyf(ptr nonnull %.this_arg, i64 %index_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %3 = getelementptr inbounds float, ptr %2, i64 %index_arg ; [#uses = 1, type = ptr]
  ret ptr %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw11__xopEqualsMxFKxSQDnQDmQDh__TQDeTQCxVmi1VQCxi2ZQDwZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %p) local_unnamed_addr #1 comdat {
  %bcmp.i = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %p, i64 8) ; [#uses = 1]
  %.not.i = icmp eq i32 %bcmp.i, 0                ; [#uses = 1]
  br i1 %.not.i, label %endif.i, label %_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

endif.i:                                          ; preds = %0
  %.unpack.i.i = load i64, ptr %.this_arg, align 8 ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i.i, 0                ; [#uses = 1]
  br i1 %1, label %_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %endif2.i

endif2.i:                                         ; preds = %endif.i
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %p, i64 8   ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit, label %label.L.i

label.L.i:                                        ; preds = %endif2.i
  %ret.sroa.0.0.copyload.i23.i = load i64, ptr %p, align 1 ; [#uses = 1]
  %.not.i.i = icmp eq i64 %ret.sroa.0.0.copyload.i23.i, %.unpack.i.i ; [#uses = 1]
  br i1 %.not.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

dowhile.i.i.i.i:                                  ; preds = %label.L.i, %dowhile.i.i.i.i
  %__param_0.sroa.4.0.i.i.i.i = phi ptr [ %12, %dowhile.i.i.i.i ], [ %4, %label.L.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i.i = phi i64 [ %11, %dowhile.i.i.i.i ], [ %.unpack.i.i, %label.L.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i.i = phi ptr [ %10, %dowhile.i.i.i.i ], [ %5, %label.L.i ] ; [#uses = 2, type = ptr]
  %7 = load float, ptr %__param_0.sroa.4.0.i.i.i.i, align 4 ; [#uses = 1]
  %8 = load float, ptr %__param_1.sroa.3.0.i.i.i.i, align 4 ; [#uses = 1]
  %9 = fcmp fast oeq float %7, %8                 ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i.i, -1   ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i.i, label %dowhile.i.i.i.i, label %_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit

_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb.exit: ; preds = %dowhile.i.i.i.i, %0, %endif.i, %endif2.i, %label.L.i
  %common.ret.op.i = phi i1 [ false, %0 ], [ true, %endif.i ], [ false, %label.L.i ], [ true, %endif2.i ], [ %9, %dowhile.i.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op.i
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8opEqualsTQCbVQBxi2ZQuMxFNaNbNiNlNeKxSQEjQEiQEd__TQEaTQDtVmi1VQDti2ZQEsZb(ptr nonnull %.this_arg, ptr dereferenceable(16) %rslice) local_unnamed_addr #1 comdat {
  %bcmp = tail call i32 @bcmp(ptr noundef nonnull dereferenceable(8) %.this_arg, ptr noundef nonnull dereferenceable(8) %rslice, i64 8) ; [#uses = 1]
  %.not = icmp eq i32 %bcmp, 0                    ; [#uses = 1]
  br i1 %.not, label %endif, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i.i, %endif2, %label.L, %endif, %0
  %common.ret.op = phi i1 [ false, %0 ], [ true, %endif ], [ false, %label.L ], [ true, %endif2 ], [ %9, %dowhile.i.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

endif:                                            ; preds = %0
  %.unpack.i = load i64, ptr %.this_arg, align 8  ; [#uses = 3]
  %1 = icmp eq i64 %.unpack.i, 0                  ; [#uses = 1]
  br i1 %1, label %common.ret, label %endif2

endif2:                                           ; preds = %endif
  %2 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %3 = getelementptr inbounds i8, ptr %rslice, i64 8 ; [#uses = 1, type = ptr]
  %4 = load ptr, ptr %2, align 8                  ; [#uses = 2]
  %5 = load ptr, ptr %3, align 8                  ; [#uses = 2]
  %6 = icmp eq ptr %4, %5                         ; [#uses = 1]
  br i1 %6, label %common.ret, label %label.L

label.L:                                          ; preds = %endif2
  %ret.sroa.0.0.copyload.i23 = load i64, ptr %rslice, align 1 ; [#uses = 1]
  %.not.i = icmp eq i64 %ret.sroa.0.0.copyload.i23, %.unpack.i ; [#uses = 1]
  br i1 %.not.i, label %dowhile.i.i.i, label %common.ret

dowhile.i.i.i:                                    ; preds = %label.L, %dowhile.i.i.i
  %__param_0.sroa.4.0.i.i.i = phi ptr [ %12, %dowhile.i.i.i ], [ %4, %label.L ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i.i = phi i64 [ %11, %dowhile.i.i.i ], [ %.unpack.i, %label.L ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i.i = phi ptr [ %10, %dowhile.i.i.i ], [ %5, %label.L ] ; [#uses = 2, type = ptr]
  %7 = load float, ptr %__param_0.sroa.4.0.i.i.i, align 4 ; [#uses = 1]
  %8 = load float, ptr %__param_1.sroa.3.0.i.i.i, align 4 ; [#uses = 1]
  %9 = fcmp fast oeq float %7, %8                 ; [#uses = 2]
  %10 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %11 = add i64 %__param_0.sroa.0.0.i.i.i, -1     ; [#uses = 2]
  %12 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i.i, i64 4 ; [#uses = 1, type = ptr]
  %13 = icmp ne i64 %11, 0                        ; [#uses = 1]
  %or.cond.not.i.i = select i1 %9, i1 %13, i1 false ; [#uses = 1]
  br i1 %or.cond.not.i.i, label %dowhile.i.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: alwaysinline uwtable
define weak_odr %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7toConstZQjMxFNaNbNiNjNlNeZSQDzQDyQDt__TQDqTPxfVmi1VQDji2ZQEi(ptr nonnull %.this_arg) local_unnamed_addr #2 comdat {
  %.structliteral.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %.structliteral.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: alwaysinline uwtable
define weak_odr %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T7toConstZQjMxFNaNbNiNjNlNeZSQDyQDxQDs__TQDpTPxfVmi1VQDji2ZQEh(ptr nonnull %.this_arg) local_unnamed_addr #2 comdat {
  %.structliteral.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %.structliteral.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T11indexStrideVmi1ZQsMxFNaNbNiNlNfG1mZm(ptr nonnull %.this_arg, [1 x i64] %_indices_arg) local_unnamed_addr #1 comdat {
  %_indices_arg.fca.0.extract = extractvalue [1 x i64] %_indices_arg, 0 ; [#uses = 1]
  ret i64 %_indices_arg.fca.0.extract
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret i64 1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T13opIndexAssignZQqMFNcNjNlNefG1mX3funFNaNbNcNiNfKfKfZf(ptr dereferenceable(4) %t, ptr dereferenceable(4) %v) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %v, align 4                ; [#uses = 1]
  store float %1, ptr %t, align 4
  ret ptr %t
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T11indexStrideVmi1ZQsMxFNaNbNiNlNfG1mZm(ptr nonnull %.this_arg, [1 x i64] %_indices_arg) local_unnamed_addr #1 comdat {
  %_indices_arg.fca.0.extract = extractvalue [1 x i64] %_indices_arg, 0 ; [#uses = 1]
  ret i64 %_indices_arg.fca.0.extract
}

; [#uses = 0]
; Function Attrs: alwaysinline uwtable
define weak_odr float @_D4core8lifetime__T7forwardS_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T13opIndexAssignZQqMFNcNjNlNefG1mX5valuefZ__T3fwdS_DQEvQEuQEp__TQEmTQEfVmi1VQEgi2ZQFe__TQDjZQDnMFNcNjNlNefQCyXQCyfZQCsMFNaNbNdNiNfZf(ptr nonnull %.nest_arg) local_unnamed_addr #2 comdat {
  %1 = load float, ptr %.nest_arg, align 4        ; [#uses = 1]
  ret float %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr float @_D4core8lifetime__T4moveTfZQiFNaNbNiNfNkMKfZf(ptr dereferenceable(4) %source) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %source, align 4           ; [#uses = 1]
  ret float %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret i64 1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr float @_D4core8lifetime__T8moveImplTfZQmFNaNbNiNfNkMKfZf(ptr dereferenceable(4) %source) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %source, align 4           ; [#uses = 1]
  ret float %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr float @_D4core8lifetime__T15trustedMoveImplTfZQuFNaNbNiNeNkMKfZf(ptr dereferenceable(4) %source) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %source, align 4           ; [#uses = 1]
  ret float %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D4core8lifetime__T15moveEmplaceImplTfZQuFNaNbNiNfMKfNkMKfZv(ptr dereferenceable(4) %target, ptr dereferenceable(4) %source) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %source, align 4           ; [#uses = 1]
  store float %1, ptr %target, align 4
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %0 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %0
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = icmp eq i64 %.unpack, 0                    ; [#uses = 1]
  ret i1 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret [1 x i64] [i64 1]
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPxhVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 3]
  %__param_1_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 0, 0 ; [#uses = 1]
  %.not = icmp eq i64 %__param_1_arg.fca.0.0.extract, %__param_0_arg.fca.0.0.extract ; [#uses = 1]
  br i1 %.not, label %unrolledend, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i, %unrolledend, %unrolledstmt
  %common.ret.op = phi i1 [ false, %unrolledstmt ], [ true, %unrolledend ], [ %3, %dowhile.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

unrolledend:                                      ; preds = %unrolledstmt
  %0 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %0, label %common.ret, label %dowhile.i.i.preheader

dowhile.i.i.preheader:                            ; preds = %unrolledend
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i.i

dowhile.i.i:                                      ; preds = %dowhile.i.i.preheader, %dowhile.i.i
  %__param_0.sroa.4.0.i.i = phi ptr [ %6, %dowhile.i.i ], [ %__param_0_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i = phi i64 [ %5, %dowhile.i.i ], [ %__param_0_arg.fca.0.0.extract, %dowhile.i.i.preheader ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i = phi ptr [ %4, %dowhile.i.i ], [ %__param_1_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %1 = load i8, ptr %__param_0.sroa.4.0.i.i, align 1 ; [#uses = 1]
  %2 = load i8, ptr %__param_1.sroa.3.0.i.i, align 1 ; [#uses = 1]
  %3 = icmp eq i8 %1, %2                          ; [#uses = 2]
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i, i64 1 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0.i.i, -1        ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i, i64 1 ; [#uses = 1, type = ptr]
  %7 = icmp ne i64 %5, 0                          ; [#uses = 1]
  %or.cond.not.i = select i1 %3, i1 %7, i1 false  ; [#uses = 1]
  br i1 %or.cond.not.i, label %dowhile.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %ret.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %ret.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir10primitives__T13anyEmptyShapeVmi1ZQuFNaNbNdNiNfMxG1mZb([1 x i64] %shape_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %shape_arg.fca.0.extract = extractvalue [1 x i64] %shape_arg, 0 ; [#uses = 1]
  %0 = icmp eq i64 %shape_arg.fca.0.extract, 0    ; [#uses = 1]
  ret i1 %0
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir9qualifier__T10lightScopeTPxhZQrFNaNbNdNiNfNkQtZQw(ptr %v_arg) local_unnamed_addr #1 comdat {
  ret ptr %v_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = insertvalue [1 x i64] poison, i64 %.unpack, 0 ; [#uses = 1]
  ret [1 x i64] %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPxhVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 2]
  %1 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %1, label %ororend, label %oror

oror:                                             ; preds = %0
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract.i = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i

dowhile.i:                                        ; preds = %dowhile.i, %oror
  %__param_0.sroa.4.0.i = phi ptr [ %__param_0_arg.fca.1.extract, %oror ], [ %7, %dowhile.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i = phi i64 [ %__param_0_arg.fca.0.0.extract, %oror ], [ %6, %dowhile.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i = phi ptr [ %__param_1_arg.fca.1.extract.i, %oror ], [ %5, %dowhile.i ] ; [#uses = 2, type = ptr]
  %2 = load i8, ptr %__param_0.sroa.4.0.i, align 1 ; [#uses = 1]
  %3 = load i8, ptr %__param_1.sroa.3.0.i, align 1 ; [#uses = 1]
  %4 = icmp eq i8 %2, %3                          ; [#uses = 2]
  %5 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i, i64 1 ; [#uses = 1, type = ptr]
  %6 = add i64 %__param_0.sroa.0.0.i, -1          ; [#uses = 2]
  %7 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i, i64 1 ; [#uses = 1, type = ptr]
  %8 = icmp ne i64 %6, 0                          ; [#uses = 1]
  %or.cond.not = select i1 %4, i1 %8, i1 false    ; [#uses = 1]
  br i1 %or.cond.not, label %dowhile.i, label %ororend

ororend:                                          ; preds = %dowhile.i, %0
  %ororval = phi i1 [ true, %0 ], [ %4, %dowhile.i ] ; [#uses = 1, type = i1]
  ret i1 %ororval
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa158_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQMna293_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128636f6e7374287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBLf7ndslice5slice__T9mir_sliceTPxhVmi1VEQBMuQBpQBk14mir_slice_kindi2ZQBxTQCxZQBNeFNaNbNiNfQDoQDrZv(%"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPxhVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm(%"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 1]
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile

dowhile:                                          ; preds = %unrolledstmt, %0
  %__param_0.sroa.4.0 = phi ptr [ %__param_0_arg.fca.1.extract, %0 ], [ %6, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0 = phi i64 [ %__param_0_arg.fca.0.0.extract, %0 ], [ %5, %unrolledstmt ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0 = phi ptr [ %__param_1_arg.fca.1.extract, %0 ], [ %4, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %1 = load i8, ptr %__param_0.sroa.4.0, align 1  ; [#uses = 1]
  %2 = load i8, ptr %__param_1.sroa.3.0, align 1  ; [#uses = 1]
  %3 = icmp eq i8 %1, %2                          ; [#uses = 1]
  br i1 %3, label %unrolledstmt, label %common.ret

common.ret:                                       ; preds = %unrolledstmt, %dowhile
  %common.ret.op = phi i64 [ 0, %dowhile ], [ 1, %unrolledstmt ] ; [#uses = 1, type = i64]
  ret i64 %common.ret.op

unrolledstmt:                                     ; preds = %dowhile
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0, i64 1 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0, -1            ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0, i64 1 ; [#uses = 1, type = ptr]
  %7 = icmp eq i64 %5, 0                          ; [#uses = 1]
  br i1 %7, label %common.ret, label %dowhile
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTxhTxhZQBrFNaNbNiNfKxhKxhZb(ptr dereferenceable(1) %__param_0, ptr dereferenceable(1) %__param_1) local_unnamed_addr #1 comdat {
  %1 = load i8, ptr %__param_0, align 1           ; [#uses = 1]
  %2 = load i8, ptr %__param_1, align 1           ; [#uses = 1]
  %3 = icmp eq i8 %1, %2                          ; [#uses = 1]
  ret i1 %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZxh(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  ret ptr %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = add i64 %1, -1                             ; [#uses = 1]
  store i64 %2, ptr %.this_arg, align 8
  %3 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 2, type = ptr]
  %4 = load ptr, ptr %3, align 8                  ; [#uses = 1]
  %5 = getelementptr inbounds i8, ptr %4, i64 1   ; [#uses = 1, type = ptr]
  store ptr %5, ptr %3, align 8
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = icmp eq i64 %1, 0                          ; [#uses = 1]
  ret i1 %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %0 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %0
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = icmp eq i64 %.unpack, 0                    ; [#uses = 1]
  ret i1 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret [1 x i64] [i64 1]
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPyhVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 3]
  %__param_1_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 0, 0 ; [#uses = 1]
  %.not = icmp eq i64 %__param_1_arg.fca.0.0.extract, %__param_0_arg.fca.0.0.extract ; [#uses = 1]
  br i1 %.not, label %unrolledend, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i, %unrolledend, %unrolledstmt
  %common.ret.op = phi i1 [ false, %unrolledstmt ], [ true, %unrolledend ], [ %3, %dowhile.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

unrolledend:                                      ; preds = %unrolledstmt
  %0 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %0, label %common.ret, label %dowhile.i.i.preheader

dowhile.i.i.preheader:                            ; preds = %unrolledend
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i.i

dowhile.i.i:                                      ; preds = %dowhile.i.i.preheader, %dowhile.i.i
  %__param_0.sroa.4.0.i.i = phi ptr [ %6, %dowhile.i.i ], [ %__param_0_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i = phi i64 [ %5, %dowhile.i.i ], [ %__param_0_arg.fca.0.0.extract, %dowhile.i.i.preheader ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i = phi ptr [ %4, %dowhile.i.i ], [ %__param_1_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %1 = load i8, ptr %__param_0.sroa.4.0.i.i, align 1 ; [#uses = 1]
  %2 = load i8, ptr %__param_1.sroa.3.0.i.i, align 1 ; [#uses = 1]
  %3 = icmp eq i8 %1, %2                          ; [#uses = 2]
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i, i64 1 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0.i.i, -1        ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i, i64 1 ; [#uses = 1, type = ptr]
  %7 = icmp ne i64 %5, 0                          ; [#uses = 1]
  %or.cond.not.i = select i1 %3, i1 %7, i1 false  ; [#uses = 1]
  br i1 %or.cond.not.i, label %dowhile.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %ret.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %ret.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret i64 1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir9qualifier__T10lightScopeTPyhZQrFNaNbNdNiNfNkQtZQw(ptr %v_arg) local_unnamed_addr #1 comdat {
  ret ptr %v_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = insertvalue [1 x i64] poison, i64 %.unpack, 0 ; [#uses = 1]
  ret [1 x i64] %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPyhVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 2]
  %1 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %1, label %ororend, label %oror

oror:                                             ; preds = %0
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract.i = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i

dowhile.i:                                        ; preds = %dowhile.i, %oror
  %__param_0.sroa.4.0.i = phi ptr [ %__param_0_arg.fca.1.extract, %oror ], [ %7, %dowhile.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i = phi i64 [ %__param_0_arg.fca.0.0.extract, %oror ], [ %6, %dowhile.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i = phi ptr [ %__param_1_arg.fca.1.extract.i, %oror ], [ %5, %dowhile.i ] ; [#uses = 2, type = ptr]
  %2 = load i8, ptr %__param_0.sroa.4.0.i, align 1 ; [#uses = 1]
  %3 = load i8, ptr %__param_1.sroa.3.0.i, align 1 ; [#uses = 1]
  %4 = icmp eq i8 %2, %3                          ; [#uses = 2]
  %5 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i, i64 1 ; [#uses = 1, type = ptr]
  %6 = add i64 %__param_0.sroa.0.0.i, -1          ; [#uses = 2]
  %7 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i, i64 1 ; [#uses = 1, type = ptr]
  %8 = icmp ne i64 %6, 0                          ; [#uses = 1]
  %or.cond.not = select i1 %4, i1 %8, i1 false    ; [#uses = 1]
  br i1 %or.cond.not, label %dowhile.i, label %ororend

ororend:                                          ; preds = %dowhile.i, %0
  %ororval = phi i1 [ true, %0 ], [ %4, %dowhile.i ] ; [#uses = 1, type = i1]
  ret i1 %ororval
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa166_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQNda309_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128696d6d757461626c65287562797465292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBNb7ndslice5slice__T9mir_sliceTPyhVmi1VEQBOqQBpQBk14mir_slice_kindi2ZQBxTQCxZQBPaFNaNbNiNfQDoQDrZv(%"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPyhVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm(%"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 1]
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(ubyte)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile

dowhile:                                          ; preds = %unrolledstmt, %0
  %__param_0.sroa.4.0 = phi ptr [ %__param_0_arg.fca.1.extract, %0 ], [ %6, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0 = phi i64 [ %__param_0_arg.fca.0.0.extract, %0 ], [ %5, %unrolledstmt ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0 = phi ptr [ %__param_1_arg.fca.1.extract, %0 ], [ %4, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %1 = load i8, ptr %__param_0.sroa.4.0, align 1  ; [#uses = 1]
  %2 = load i8, ptr %__param_1.sroa.3.0, align 1  ; [#uses = 1]
  %3 = icmp eq i8 %1, %2                          ; [#uses = 1]
  br i1 %3, label %unrolledstmt, label %common.ret

common.ret:                                       ; preds = %unrolledstmt, %dowhile
  %common.ret.op = phi i64 [ 0, %dowhile ], [ 1, %unrolledstmt ] ; [#uses = 1, type = i64]
  ret i64 %common.ret.op

unrolledstmt:                                     ; preds = %dowhile
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0, i64 1 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0, -1            ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0, i64 1 ; [#uses = 1, type = ptr]
  %7 = icmp eq i64 %5, 0                          ; [#uses = 1]
  br i1 %7, label %common.ret, label %dowhile
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTyhTyhZQBrFNaNbNiNfKyhKyhZb(ptr dereferenceable(1) %__param_0, ptr dereferenceable(1) %__param_1) local_unnamed_addr #1 comdat {
  %1 = load i8, ptr %__param_0, align 1           ; [#uses = 1]
  %2 = load i8, ptr %__param_1, align 1           ; [#uses = 1]
  %3 = icmp eq i8 %1, %2                          ; [#uses = 1]
  ret i1 %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZyh(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  ret ptr %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = add i64 %1, -1                             ; [#uses = 1]
  store i64 %2, ptr %.this_arg, align 8
  %3 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 2, type = ptr]
  %4 = load ptr, ptr %3, align 8                  ; [#uses = 1]
  %5 = getelementptr inbounds i8, ptr %4, i64 1   ; [#uses = 1, type = ptr]
  store ptr %5, ptr %3, align 8
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyhVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = icmp eq i64 %1, 0                          ; [#uses = 1]
  ret i1 %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T12elementCountZQpMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %0 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %0
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T8anyEmptyZQkMxFNaNbNdNiNlNeZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = icmp eq i64 %.unpack, 0                    ; [#uses = 1]
  ret i1 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T7stridesZQjMxFNaNbNdNiNlNeZG1l(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret [1 x i64] [i64 1]
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPxfVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 3]
  %__param_1_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 0, 0 ; [#uses = 1]
  %.not = icmp eq i64 %__param_1_arg.fca.0.0.extract, %__param_0_arg.fca.0.0.extract ; [#uses = 1]
  br i1 %.not, label %unrolledend, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i, %unrolledend, %unrolledstmt
  %common.ret.op = phi i1 [ false, %unrolledstmt ], [ true, %unrolledend ], [ %3, %dowhile.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

unrolledend:                                      ; preds = %unrolledstmt
  %0 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %0, label %common.ret, label %dowhile.i.i.preheader

dowhile.i.i.preheader:                            ; preds = %unrolledend
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i.i

dowhile.i.i:                                      ; preds = %dowhile.i.i.preheader, %dowhile.i.i
  %__param_0.sroa.4.0.i.i = phi ptr [ %6, %dowhile.i.i ], [ %__param_0_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i = phi i64 [ %5, %dowhile.i.i ], [ %__param_0_arg.fca.0.0.extract, %dowhile.i.i.preheader ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i = phi ptr [ %4, %dowhile.i.i ], [ %__param_1_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %1 = load float, ptr %__param_0.sroa.4.0.i.i, align 4 ; [#uses = 1]
  %2 = load float, ptr %__param_1.sroa.3.0.i.i, align 4 ; [#uses = 1]
  %3 = fcmp fast oeq float %1, %2                 ; [#uses = 2]
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i, i64 4 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0.i.i, -1        ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i, i64 4 ; [#uses = 1, type = ptr]
  %7 = icmp ne i64 %5, 0                          ; [#uses = 1]
  %or.cond.not.i = select i1 %3, i1 %7, i1 false  ; [#uses = 1]
  br i1 %or.cond.not.i, label %dowhile.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPfVmi1VEQBoQBnQBi14mir_slice_kindi2ZQBv__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEeQEdQDy__TQDvTPxfVmi1VQDpi2ZQEn(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %ret.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %ret.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir9qualifier__T10lightScopeTPxfZQrFNaNbNdNiNfNkQtZQw(ptr %v_arg) local_unnamed_addr #1 comdat {
  ret ptr %v_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = insertvalue [1 x i64] poison, i64 %.unpack, 0 ; [#uses = 1]
  ret [1 x i64] %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPxfVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 2]
  %1 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %1, label %ororend, label %oror

oror:                                             ; preds = %0
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract.i = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i

dowhile.i:                                        ; preds = %dowhile.i, %oror
  %__param_0.sroa.4.0.i = phi ptr [ %__param_0_arg.fca.1.extract, %oror ], [ %7, %dowhile.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i = phi i64 [ %__param_0_arg.fca.0.0.extract, %oror ], [ %6, %dowhile.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i = phi ptr [ %__param_1_arg.fca.1.extract.i, %oror ], [ %5, %dowhile.i ] ; [#uses = 2, type = ptr]
  %2 = load float, ptr %__param_0.sroa.4.0.i, align 4 ; [#uses = 1]
  %3 = load float, ptr %__param_1.sroa.3.0.i, align 4 ; [#uses = 1]
  %4 = fcmp fast oeq float %2, %3                 ; [#uses = 2]
  %5 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i, i64 4 ; [#uses = 1, type = ptr]
  %6 = add i64 %__param_0.sroa.0.0.i, -1          ; [#uses = 2]
  %7 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i, i64 4 ; [#uses = 1, type = ptr]
  %8 = icmp ne i64 %6, 0                          ; [#uses = 1]
  %or.cond.not = select i1 %4, i1 %8, i1 false    ; [#uses = 1]
  br i1 %or.cond.not, label %dowhile.i, label %ororend

ororend:                                          ; preds = %dowhile.i, %0
  %ororval = phi i1 [ true, %0 ], [ %4, %dowhile.i ] ; [#uses = 1, type = i1]
  ret i1 %ororval
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa158_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQMna293_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128636f6e737428666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBLf7ndslice5slice__T9mir_sliceTPxfVmi1VEQBMuQBpQBk14mir_slice_kindi2ZQBxTQCxZQBNeFNaNbNiNfQDoQDrZv(%"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = icmp eq i64 %.unpack, 0                    ; [#uses = 1]
  ret i1 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPxfVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm(%"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 1]
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile

dowhile:                                          ; preds = %unrolledstmt, %0
  %__param_0.sroa.4.0 = phi ptr [ %__param_0_arg.fca.1.extract, %0 ], [ %6, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0 = phi i64 [ %__param_0_arg.fca.0.0.extract, %0 ], [ %5, %unrolledstmt ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0 = phi ptr [ %__param_1_arg.fca.1.extract, %0 ], [ %4, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %1 = load float, ptr %__param_0.sroa.4.0, align 4 ; [#uses = 1]
  %2 = load float, ptr %__param_1.sroa.3.0, align 4 ; [#uses = 1]
  %3 = fcmp fast oeq float %1, %2                 ; [#uses = 1]
  br i1 %3, label %unrolledstmt, label %common.ret

common.ret:                                       ; preds = %unrolledstmt, %dowhile
  %common.ret.op = phi i64 [ 0, %dowhile ], [ 1, %unrolledstmt ] ; [#uses = 1, type = i64]
  ret i64 %common.ret.op

unrolledstmt:                                     ; preds = %dowhile
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0, i64 4 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0, -1            ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0, i64 4 ; [#uses = 1, type = ptr]
  %7 = icmp eq i64 %5, 0                          ; [#uses = 1]
  br i1 %7, label %common.ret, label %dowhile
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTxfTxfZQBrFNaNbNiNfKxfKxfZb(ptr dereferenceable(4) %__param_0, ptr dereferenceable(4) %__param_1) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %__param_0, align 4        ; [#uses = 1]
  %2 = load float, ptr %__param_1, align 4        ; [#uses = 1]
  %3 = fcmp fast oeq float %1, %2                 ; [#uses = 1]
  ret i1 %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZxf(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  ret ptr %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = add i64 %1, -1                             ; [#uses = 1]
  store i64 %2, ptr %.this_arg, align 8
  %3 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 2, type = ptr]
  %4 = load ptr, ptr %3, align 8                  ; [#uses = 1]
  %5 = getelementptr inbounds i8, ptr %4, i64 4   ; [#uses = 1, type = ptr]
  store ptr %5, ptr %3, align 8
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = icmp eq i64 %1, 0                          ; [#uses = 1]
  ret i1 %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %0 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %0
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret [1 x i64] [i64 1]
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %ret.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %ret.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(const(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPxfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret i64 1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T12elementCountZQpMxFNaNbNdNiNlNfZm(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %0 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  ret i64 %0
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8anyEmptyZQkMxFNaNbNdNiNlNeZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = icmp eq i64 %.unpack, 0                    ; [#uses = 1]
  ret i1 %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7stridesZQjMxFNaNbNdNiNlNeZG1l(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret [1 x i64] [i64 1]
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T5equalSQBi10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCkTSQDq7ndslice5slice__T9mir_sliceTPyfVmi1VEQFeQBoQBj14mir_slice_kindi2ZQBwTQCvZQFnFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 3]
  %__param_1_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 0, 0 ; [#uses = 1]
  %.not = icmp eq i64 %__param_1_arg.fca.0.0.extract, %__param_0_arg.fca.0.0.extract ; [#uses = 1]
  br i1 %.not, label %unrolledend, label %common.ret

common.ret:                                       ; preds = %dowhile.i.i, %unrolledend, %unrolledstmt
  %common.ret.op = phi i1 [ false, %unrolledstmt ], [ true, %unrolledend ], [ %3, %dowhile.i.i ] ; [#uses = 1, type = i1]
  ret i1 %common.ret.op

unrolledend:                                      ; preds = %unrolledstmt
  %0 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %0, label %common.ret, label %dowhile.i.i.preheader

dowhile.i.i.preheader:                            ; preds = %unrolledend
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i.i

dowhile.i.i:                                      ; preds = %dowhile.i.i.preheader, %dowhile.i.i
  %__param_0.sroa.4.0.i.i = phi ptr [ %6, %dowhile.i.i ], [ %__param_0_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i.i = phi i64 [ %5, %dowhile.i.i ], [ %__param_0_arg.fca.0.0.extract, %dowhile.i.i.preheader ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i.i = phi ptr [ %4, %dowhile.i.i ], [ %__param_1_arg.fca.1.extract, %dowhile.i.i.preheader ] ; [#uses = 2, type = ptr]
  %1 = load float, ptr %__param_0.sroa.4.0.i.i, align 4 ; [#uses = 1]
  %2 = load float, ptr %__param_1.sroa.3.0.i.i, align 4 ; [#uses = 1]
  %3 = fcmp fast oeq float %1, %2                 ; [#uses = 2]
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i.i, i64 4 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0.i.i, -1        ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i.i, i64 4 ; [#uses = 1, type = ptr]
  %7 = icmp ne i64 %5, 0                          ; [#uses = 1]
  %or.cond.not.i = select i1 %3, i1 %7, i1 false  ; [#uses = 1]
  br i1 %or.cond.not.i, label %dowhile.i.i, label %common.ret
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T10lightScopeZQnMxFNaNbNdNiNjNlNeZSQEfQEeQDz__TQDwTQDpVmi1VQDpi2ZQEo(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %ret.sroa.0.0.copyload = load i64, ptr %.this_arg, align 1 ; [#uses = 1]
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  %.fca.0.0.insert = insertvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" poison, i64 %ret.sroa.0.0.copyload, 0, 0 ; [#uses = 1]
  %.fca.1.insert = insertvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.0.0.insert, ptr %2, 1 ; [#uses = 1]
  ret %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %.fca.1.insert
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T7_strideVmi0ZQnMxFNaNbNdNiNlNfZl(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  ret i64 1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir9qualifier__T10lightScopeTPyfZQrFNaNbNdNiNfNkQtZQw(ptr %v_arg) local_unnamed_addr #1 comdat {
  ret ptr %v_arg
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr [1 x i64] @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5shapeZQhMxFNaNbNdNiNlNeZG1m(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %.unpack = load i64, ptr %.this_arg, align 8    ; [#uses = 1]
  %1 = insertvalue [1 x i64] poison, i64 %.unpack, 0 ; [#uses = 1]
  ret [1 x i64] %1
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir9algorithm9iteration__T3allSQBg10functional__T9stringFunVAyaa6_61203d3d2062ZQBeZ__TQCiTSQDo7ndslice5slice__T9mir_sliceTPyfVmi1VEQFcQBoQBj14mir_slice_kindi2ZQBwTQCvZQFlFNaNbNiNfQDlQDoZb(%"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 2]
  %1 = icmp eq i64 %__param_0_arg.fca.0.0.extract, 0 ; [#uses = 1]
  br i1 %1, label %ororend, label %oror

oror:                                             ; preds = %0
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract.i = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile.i

dowhile.i:                                        ; preds = %dowhile.i, %oror
  %__param_0.sroa.4.0.i = phi ptr [ %__param_0_arg.fca.1.extract, %oror ], [ %7, %dowhile.i ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0.i = phi i64 [ %__param_0_arg.fca.0.0.extract, %oror ], [ %6, %dowhile.i ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0.i = phi ptr [ %__param_1_arg.fca.1.extract.i, %oror ], [ %5, %dowhile.i ] ; [#uses = 2, type = ptr]
  %2 = load float, ptr %__param_0.sroa.4.0.i, align 4 ; [#uses = 1]
  %3 = load float, ptr %__param_1.sroa.3.0.i, align 4 ; [#uses = 1]
  %4 = fcmp fast oeq float %2, %3                 ; [#uses = 2]
  %5 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0.i, i64 4 ; [#uses = 1, type = ptr]
  %6 = add i64 %__param_0.sroa.0.0.i, -1          ; [#uses = 2]
  %7 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0.i, i64 4 ; [#uses = 1, type = ptr]
  %8 = icmp ne i64 %6, 0                          ; [#uses = 1]
  %or.cond.not = select i1 %4, i1 %8, i1 false    ; [#uses = 1]
  br i1 %or.cond.not, label %dowhile.i, label %ororend

ororend:                                          ; preds = %dowhile.i, %0
  %ororval = phi i1 [ true, %0 ], [ %4, %dowhile.i ] ; [#uses = 1, type = i1]
  ret i1 %ororval
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir9algorithm9iteration__T16checkShapesMatchVAyaa166_6d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6cVQNda309_626f6f6c206d69722e616c676f726974686d2e697465726174696f6e2e616c6c2128737472696e6746756e292e616c6c2128536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f7573292c20536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329292e616c6c28536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f302c20536c6963652128696d6d757461626c6528666c6f6174292a2c20314c552c206d69725f736c6963655f6b696e642e636f6e746967756f757329205f5f706172616d5f3129TSQBNb7ndslice5slice__T9mir_sliceTPyfVmi1VEQBOqQBpQBk14mir_slice_kindi2ZQBxTQCxZQBPaFNaNbNiNfQDoQDrZv(%"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
unrolledstmt:
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr i64 @_D3mir9algorithm9iteration__T7allImplSQBk10functional__T9stringFunVAyaa6_61203d3d2062ZQBeTSQDl7ndslice5slice__T9mir_sliceTPyfVmi1VEQEzQBoQBj14mir_slice_kindi2ZQBwTQCvZQFiFNaNbNiNfQDlQDoZm(%"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg) local_unnamed_addr #1 comdat {
  %__param_0_arg.fca.0.0.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 0, 0 ; [#uses = 1]
  %__param_0_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_0_arg, 1 ; [#uses = 1]
  %__param_1_arg.fca.1.extract = extractvalue %"mir.ndslice.slice.Slice!(immutable(float)*, 1LU, mir_slice_kind.contiguous).mir_slice" %__param_1_arg, 1 ; [#uses = 1]
  br label %dowhile

dowhile:                                          ; preds = %unrolledstmt, %0
  %__param_0.sroa.4.0 = phi ptr [ %__param_0_arg.fca.1.extract, %0 ], [ %6, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %__param_0.sroa.0.0 = phi i64 [ %__param_0_arg.fca.0.0.extract, %0 ], [ %5, %unrolledstmt ] ; [#uses = 1, type = i64]
  %__param_1.sroa.3.0 = phi ptr [ %__param_1_arg.fca.1.extract, %0 ], [ %4, %unrolledstmt ] ; [#uses = 2, type = ptr]
  %1 = load float, ptr %__param_0.sroa.4.0, align 4 ; [#uses = 1]
  %2 = load float, ptr %__param_1.sroa.3.0, align 4 ; [#uses = 1]
  %3 = fcmp fast oeq float %1, %2                 ; [#uses = 1]
  br i1 %3, label %unrolledstmt, label %common.ret

common.ret:                                       ; preds = %unrolledstmt, %dowhile
  %common.ret.op = phi i64 [ 0, %dowhile ], [ 1, %unrolledstmt ] ; [#uses = 1, type = i64]
  ret i64 %common.ret.op

unrolledstmt:                                     ; preds = %dowhile
  %4 = getelementptr inbounds i8, ptr %__param_1.sroa.3.0, i64 4 ; [#uses = 1, type = ptr]
  %5 = add i64 %__param_0.sroa.0.0, -1            ; [#uses = 2]
  %6 = getelementptr inbounds i8, ptr %__param_0.sroa.4.0, i64 4 ; [#uses = 1, type = ptr]
  %7 = icmp eq i64 %5, 0                          ; [#uses = 1]
  br i1 %7, label %common.ret, label %dowhile
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir10functional__T9stringFunVAyaa6_61203d3d2062Z__TQBhTyfTyfZQBrFNaNbNiNfKyfKyfZb(ptr dereferenceable(4) %__param_0, ptr dereferenceable(4) %__param_1) local_unnamed_addr #1 comdat {
  %1 = load float, ptr %__param_0, align 4        ; [#uses = 1]
  %2 = load float, ptr %__param_1, align 4        ; [#uses = 1]
  %3 = fcmp fast oeq float %1, %2                 ; [#uses = 1]
  ret i1 %3
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr ptr @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5frontVii0ZQlMFNaNbNcNdNiNjNlNeZyf(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 1, type = ptr]
  %2 = load ptr, ptr %1, align 8                  ; [#uses = 1]
  ret ptr %2
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr void @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T8popFrontVii0ZQoMFNaNbNiNlNeZv(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = add i64 %1, -1                             ; [#uses = 1]
  store i64 %2, ptr %.this_arg, align 8
  %3 = getelementptr inbounds i8, ptr %.this_arg, i64 8 ; [#uses = 2, type = ptr]
  %4 = load ptr, ptr %3, align 8                  ; [#uses = 1]
  %5 = getelementptr inbounds i8, ptr %4, i64 4   ; [#uses = 1, type = ptr]
  store ptr %5, ptr %3, align 8
  ret void
}

; [#uses = 0]
; Function Attrs: uwtable
define weak_odr zeroext i1 @_D3mir7ndslice5slice__T9mir_sliceTPyfVmi1VEQBpQBoQBj14mir_slice_kindi2ZQBw__T5emptyVmi0ZQlMxFNaNbNdNiNlNfZb(ptr nonnull %.this_arg) local_unnamed_addr #1 comdat {
  %1 = load i64, ptr %.this_arg, align 8          ; [#uses = 1]
  %2 = icmp eq i64 %1, 0                          ; [#uses = 1]
  ret i1 %2
}

; [#uses = 10]
; Function Attrs: nofree nounwind willreturn memory(argmem: read)
declare i32 @bcmp(ptr nocapture, ptr nocapture, i64) local_unnamed_addr #3

attributes #0 = { nofree norecurse nosync nounwind memory(readwrite, inaccessiblemem: none) uwtable "frame-pointer"="none" "target-cpu"="x86-64" "target-features"="+cx16" }
attributes #1 = { uwtable "frame-pointer"="none" "target-cpu"="x86-64" "target-features"="+cx16" }
attributes #2 = { alwaysinline uwtable "frame-pointer"="none" "target-cpu"="x86-64" "target-features"="+cx16" }
attributes #3 = { nofree nounwind willreturn memory(argmem: read) }

!llvm.ident = !{!0}

!0 = !{!"ldc version 1.41.0"}
!1 = distinct !{!1, !2}
!2 = !{!"llvm.loop.unroll.disable"}
!3 = !{!4}
!4 = distinct !{!4, !5}
!5 = distinct !{!5, !"LVerDomain"}
!6 = !{!7}
!7 = distinct !{!7, !5}
!8 = distinct !{!8, !9, !10}
!9 = !{!"llvm.loop.isvectorized", i32 1}
!10 = !{!"llvm.loop.unroll.runtime.disable"}
!11 = distinct !{!11, !9}
