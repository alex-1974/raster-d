# v0.2 M5.7 comparable C++ convolution gate

This retained diagnostic applies the M5.7 comparable-C++ rule to the strongest
remaining current x86-64 compiler gap: fixed 3x3 float convolution.

It compares:

- `public_convolution`: production `convolveInto!(FixedKernel, float)`;
- `direct_scalar`: validation-free D pointer control;
- `cpp_scalar`: validation-free C++ pointer reference.

The D and C++ scalar controls perform exactly the same semantic work:

- float source/output;
- float accumulator;
- nine fixed float coefficients;
- the same row-major nine-term addition order per output pixel;
- identical generated padded source layout;
- compact destination;
- no allocation in the timed kernel;
- no border synthesis;
- no hidden threading.

C++ is built with `-O3 -std=c++20 -fno-fast-math -ffp-contract=off`.
Auto-vectorization across independent output pixels is permitted because it does
not reassociate the nine-term reduction within a pixel.

The C++ control is not a complete RasterView validation implementation.
Therefore:

- D `direct_scalar / cpp_scalar` is the fair execution-kernel comparison;
- D `public_convolution / direct_scalar` separately exposes D public
  validation/dispatch/source-form cost.

All implementations must produce the same exact output checksum.

A material D/C++ execution gap must be closed, explained by generated code or
compiler/platform behavior, or explicitly accepted as a portability trade-off.
