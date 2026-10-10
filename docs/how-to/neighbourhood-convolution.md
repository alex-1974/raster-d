# Understand neighbourhoods and fixed convolution

A single raster cell may be too little information for a calculation.
To smooth a measurement, detect a local pattern or calculate a value from
neighbours, the operation needs a *neighbourhood* around each output cell.

For a centered 3 × 3 neighbourhood, the cell `E` is surrounded by
eight other values:

```text
A B C
D E F
G H I
```

A fixed convolution multiplies each neighbour by one compile-time coefficient
and adds the nine products in the specified order. An *identity* kernel
uses coefficient 1 for the centre and zero for the other eight entries.
For finite ordinary inputs, it preserves the centre value in the usual
non-exceptional cases. It is **not** an unconditional identity for all IEEE
floating-point inputs: multiplying a zero coefficient by `NaN` or infinity
produces `NaN`, and signed-zero details are governed by the documented
convolution accumulation order. The kernel executes every coefficient term;
it does not skip terms whose coefficient is zero.

## The public building blocks

```d
import raster;

alias Shape = NeighbourhoodShape!(3, 3, 1, 1);

alias Identity = FixedConvolutionKernel!(
    Shape,
    float,
    0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f
);
```

`NeighbourhoodShape!(3, 3, 1, 1)` means a 3 × 3 window with its
anchor one column and one row from the top-left. Coefficients are listed
in row-major order. This `Identity` is a compile-time kernel
definition: it does not allocate raster storage or filter anything
by itself.

Given a validated `RasterView!float source`, a separately certified
`WritableRasterView!float destination`, and a suitable output region,
the public call has this form:

```d
RasterNeighbourhoodError error;
bool success = source.convolveInto!(Identity, float)(
    0,
    Region2D(1, 1, 1, 1),
    destination,
    0,
    error
);
```

The first `0` selects the source plane; the second selects the
destination plane. `float` is the chosen accumulation type. Always
check `success` and inspect `error` on failure.

The above is an **API call fragment**, not a standalone program:
`source` and `destination` must have been created from valid
backing resources, and destination geometry must match the selected
output contract. For a complete owned-raster construction, begin with
[the first raster](../tutorial/getting-started.md) and
[the exact conversion guide](convert-samples.md).

## Why the border needs special care

Imagine a source grid with 5 × 5 values. A centered 3 × 3 operation
calculating the interior 3 × 3 outputs needs the surrounding one-cell
margin (a *halo*):

```text
5 × 5 source
+-----------+
| h h h h h |
| h o o o h |
| h o o o h |
| h o o o h |
| h h h h h |
+-----------+
h = neighbour data needed around outputs
o = output positions
```

The source-output region refers to the **coordinates of the output
centres in the source**, not to a promise that missing neighbours
will be created automatically.

For a centered 3 × 3 kernel, outputs at the outer edge require
neighbours that may lie outside the source. The current fixed
convolution does **not** silently clamp, mirror, wrap or fill those
missing values. A caller must request an output region for which
the required neighbourhood is resident and valid.

This becomes particularly important with blocks of a large raster:
a block's output cells may require a *larger input block* that
includes a halo from its neighbours. Splitting work into blocks
must not silently change the computed results.

## What the library provides—and what it does not

`convolveInto` delegates spatial traversal to the public
neighbourhood execution family. It uses caller-owned destination
storage, performs no hidden allocation or worker scheduling, and
preserves the documented coefficient and arithmetic order.

The application remains responsible for:

- providing valid source backing that includes the required halo;
- choosing the destination and its writable lifetime;
- deciding what the values mean (height, intensity, temperature);
- selecting an appropriate numerical filter and boundary policy.

The fixed convolution family currently supports the documented
floating sample/coefficient/accumulator combinations; do not assume
integer convolutions or arbitrary narrowing are available.

For a practical first task, see
[Inspect a zero-copy region](inspect-roi.md). The
[accuracy guide](../accuracy-and-validation.md) explains why
convolution ordering matters; the generated public Ddoc/DDox
reference contains complete signatures and error contracts.
