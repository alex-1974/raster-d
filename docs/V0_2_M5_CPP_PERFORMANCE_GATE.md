# raster-d v0.2 M5.7 — comparable C++ performance gate

Status: complete.

## Goal

M5.7 requires material performance gaps against high-quality comparable C++
implementations to be investigated under controlled semantics.

A material gap must be one of:

1. closed;
2. explained by non-equivalent work or semantics; or
3. explicitly accepted as a justified compiler, platform or portability
   trade-off.

The gate is not a generic language benchmark and must never compare unlike
semantic work.

## Comparison contract

A valid D/C++ comparison controls, as applicable:

- semantic work;
- sample/output precision;
- arithmetic order;
- validation included in timing;
- failure behavior;
- allocation;
- safety configuration;
- workload dimensions;
- physical layout and strides;
- threading;
- compiler optimization mode.

When a C++ reference omits RasterView/backing validation, the equivalent D
validation-free executor is the fair comparison target. Public D API overhead
must be reported separately.

## Existing evidence

### Strict sum

`benchmark/v0_2_sum` already provides a representative strict-scalar C++
reference for `float -> double` sum.

The C++ reference preserves:

- one double accumulator;
- exact logical row-major encounter order;
- no reassociation;
- no fast-math;
- no contraction;
- no tree/fixed-lane reduction;
- identical generated padded-row values.

It is explicitly documented as a kernel-level reference rather than a complete
RasterView validation implementation.

### Copy and exact conversion

M3.5 research already used strict C++ execution references for Copy/conversion.

Those results were deliberately separated into:

- complete public/combined D consumer ratios;
- combined/C++ execution-reference ratios.

The research explicitly warns that combined/C++ is not a whole-library or
whole-language ratio.

This separation is retained as M5.7 policy.

## Fixed 3x3 convolution gate

The strongest remaining current x86-64 compiler gap was fixed 3x3 float
convolution.

The retained M5.7 diagnostic is:

- benchmark: `benchmark/v0_2_cpp_convolution`;
- archive:
  `raster-v0.2-cpp-convolution-20261008-105810.tar.gz`;
- archive SHA256:
  `4f63d7f19cb17681562e4d23ea42dc48afacd86b82ec46c14a0d5b1383315f8a`;
- benchmark head:
  `ce8270f829f114d418d7b1050d65ce56a54932a1`;
- exact checksum:
  `7596c236fe0ac383`.

The recursive SHA256 manifest verifies completely.

Environment:

- Intel Core i7-9750H;
- Linux x86-64;
- CPU0 affinity;
- DMD 2.111.0;
- LDC 1.41.0 / LLVM 19.1.7;
- g++ 15.2.0;
- six independent processes per implementation.

## Semantic equivalence

The fair D and C++ execution controls both use:

- float source and output;
- float accumulator;
- nine identical fixed float coefficients;
- the same nine-term row-major per-pixel addition order;
- the same generated padded source layout;
- compact output;
- no timed allocation;
- no border synthesis;
- no hidden threading.

The C++ build uses:

`-O3 -std=c++20 -fno-fast-math -ffp-contract=off`

Auto-vectorization across independent output pixels is permitted because it
does not reassociate the nine-term reduction inside one output pixel.

All paths produce the same exact checksum.

## Reference result

Median ns/pixel:

| implementation | median |
| --- | ---: |
| DMD production | 4.576534 |
| DMD direct scalar | 3.095233 |
| LDC production | 0.658810 |
| LDC direct scalar | 0.667233 |
| g++ comparable reference | 0.687407 |

Fair execution-kernel ratios:

- DMD direct / C++: 4.502764x;
- LDC direct / C++: 0.970651x.

Public/source-form separation:

- DMD public / direct: 1.478575x;
- LDC public / direct: 0.987377x.

The LDC/C++ difference is treated as parity, not as a portable claim that D is
faster than C++.

## Code-generation explanation

g++ and LDC both transform the scalar source form into packed SIMD across four
independent output pixels using `movups`, `mulps` and `addps`.

DMD leaves the equivalent direct D source form scalar with
`movss`, `mulss` and `addss`.

Therefore the material DMD gap is a compiler/code-generation gap, not a
difference in:

- numerical precision;
- arithmetic order;
- layout;
- allocation;
- raster validation;
- failure behavior;
- threading.

## Explicit-SIMD cross-check

M5.4 independently tested benchmark-local `core.simd.float4` for the same
fixed-convolution shape.

Result:

- DMD explicit SIMD was about 2.01x slower than the DMD direct scalar control;
- LDC explicit SIMD provided no material gain over its auto-vectorized scalar
  source.

Disassembly showed that DMD emitted packed SSE for the explicit SIMD form but
with unfavorable constant/intermediate lowering and stack traffic.

Thus both practical D-side routes were investigated:

1. portable compiler-friendly scalar source;
2. explicit D SIMD.

Neither closes the DMD gap.

## M5.7 decision

### LDC

The comparable C++ gate is closed.

LDC direct execution is at C++ parity on the qualified fixed-convolution
reference workload.

This satisfies the workspace performance target for the primary optimized
compiler without semantic weakening.

### DMD

The material 4.50x fixed-convolution execution gap is explicitly accepted as a
compiler/code-generation trade-off on the qualified x86-64 baseline.

This acceptance is justified because:

- the work and results are semantically equivalent;
- the gap is isolated below public validation;
- portable D scalar source was investigated;
- explicit D SIMD was investigated and rejected on evidence;
- no semantic weakening is acceptable;
- the workspace uses LDC as the primary optimized/codegen compiler while DMD is
  the development/correctness baseline.

This is not permission to ignore future DMD improvements. New compiler
generations may be requalified and may remove the accepted trade-off.

## Gate for future operation families

A new material D/C++ gap must not be summarized as "C++ is faster" without
decomposition.

The required sequence is:

1. define equivalent semantic work;
2. match precision and numerical order;
3. match workload/layout;
4. separate validation/allocation/safety differences;
5. compare the closest execution kernels;
6. inspect generated code when the gap is material;
7. attempt a D-appropriate source-form or compiler specialization when justified;
8. close, explain, or explicitly accept the remaining gap.

Compiler- or ISA-specific selection remains an internal implementation detail.

## Conclusion

M5.7 establishes a durable comparable-C++ gate and applies it to the strongest
remaining current v0.2 kernel.

On the qualified x86-64 reference platform:

- LDC reaches comparable C++ performance for fixed 3x3 float convolution;
- DMD retains a documented compiler-codegen trade-off after both portable
  scalar and explicit SIMD alternatives were investigated;
- no public API, numerical contract, safety contract or scheduling behavior is
  weakened to obtain the result.
