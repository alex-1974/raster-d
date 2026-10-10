# Sum the values of a raster plane

Suppose a small measurement grid contains four integer values:

```text
10  20
30  40
```

Its sum is 100. You could add those values yourself, but a raster reduction
also works with validated views of different supported storage layouts.
In v0.2, `sum` is the public checked reduction operation.

## Complete D example

```d
import core.stdc.stdlib : malloc;
import raster;

void main() @system
{
    void* memory = malloc(4);
    assert(memory !is null);
    auto samples = (cast(ubyte*) memory)[0 .. 4];
    samples[] = [10, 20, 30, 40];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 4, resource));

    const PlaneByteLayout[1] layout = [
        PlaneByteLayout(0, 2, 1)
    ];
    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource, layout[], Region2D(0, 0, 2, 2), lease
    ).ok);

    scope auto source = lease.view();

    // A wider accumulator holds the sum of the four bytes.
    const result = source.sum!ulong(0);
    assert(result.ok);
    assert(result.value == 100UL);
}
```

The index `0` selects the first logical plane (band). `sum!ulong` uses a
`ulong` accumulator for these `ubyte` samples. This is the same public
operation as `sum!ulong(source, 0)`; the call above uses D's UFCS syntax.

## Why check the result?

The v0.2 sum operation returns `RasterSumResult!Accumulator`. Always check
`result.ok` before relying on `result.value`.

- `RasterSumError.invalidPlane` means the selected plane does not exist.
- `RasterSumError.accumulatorOverflow` reports checked integer overflow.
- An unsuccessful result has no partial accumulated value exposed as success.

The operation visits cells in logical row-major order, independent of their
physical layout, and does not launch worker threads or retain the source.
For floating values, arithmetic and accumulation-type rules matter; choose
a supported sample/accumulator pair documented in the public API rather
than assuming arbitrary conversions are valid.

## Ownership and cost

The example's `RasterLease` retains the adopted physical memory on a
successful import. The `RasterView` merely borrows it and must not outlive
the backing; do not manually free memory after a successful ownership
transfer. The reduction does not need to copy the grid.

This example is deliberately small. For a child ROI, use
[Inspect a region without copying](inspect-roi.md) to select the region,
then reduce the resulting view where the public operation permits it.

For complete result types, allowable accumulator pairs and numerical
semantics consult the generated public API reference and
[Accuracy and validation](../accuracy-and-validation.md).
