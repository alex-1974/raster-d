# v0.2 M5.4 explicit SIMD convolution diagnostic

This retained diagnostic asks whether handwritten SIMD has a material advantage
over the current production and scalar source forms for one representative
fixed 3x3 float convolution.

It compares the same Canonical padded source and compact destination through:

- `public_convolution`: production `convolveInto!(FixedKernel, float)`;
- `direct_scalar`: benchmark-local direct scalar row traversal with the same
  nine terms, float accumulator, row-major term order and one float result;
- `explicit_float4`: benchmark-local `core.simd.float4` traversal across
  four adjacent output pixels, using unaligned vector loads/stores and the same
  per-lane nine-term arithmetic order, plus the scalar tail.

The explicit SIMD path is diagnostic only. It is not a proposed public API,
does not establish an ISA dispatch policy, and is not promoted merely for
winning this microbenchmark.

Qualification requires:

- exact output checksum equality across all three paths;
- unchanged destination geometry;
- DMD 2.111 and LDC 1.41 release builds;
- six CPU-pinned independent processes per compiler;
- complete compiler/platform/frequency metadata;
- complete `objdump -d -C` disassembly;
- recursive SHA256 manifest.

A production SIMD candidate is justified only if the explicit SIMD path wins
materially and reproducibly after accounting for compiler-generated vector code
and the public/semantic boundary.
