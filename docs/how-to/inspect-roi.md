# Inspect a raster region without copying

A raster can represent measurements rather than an image. Suppose a 3 × 3 grid contains:

```text
10 20 30
40 50 60
70 80 90
```

We want the bottom-right 2 × 2 region: `50, 60, 80, 90`. Its sum is 280.
A *region of interest* (ROI) borrows the same retained storage instead of copying those four values.

## Complete example

```d
import core.stdc.stdlib : malloc;
import raster;

void main() @system
{
    void* memory = malloc(9);
    assert(memory !is null);
    auto samples = (cast(ubyte*) memory)[0 .. 9];
    samples[] = [10, 20, 30, 40, 50, 60, 70, 80, 90];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 9, resource));

    // Byte offset, row stride, sample stride.
    const PlaneByteLayout[1] layout = [PlaneByteLayout(0, 3, 1)];
    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource, layout[], Region2D(0, 0, 3, 3), lease
    ).ok);

    scope auto whole = lease.view();
    bool valid;
    scope auto corner = whole.tryRoi(Region2D(1, 1, 2, 2), valid);
    assert(valid);
    assert(corner.width == 2 && corner.height == 2);

    uint total;
    foreach (y; 0 .. corner.height)
        foreach (x; 0 .. corner.width)
        {
            ubyte value;
            assert(corner.trySample(0, x, y, value));
            total += value;
        }

    assert(total == 280);
}
```

The storage is malloc-backed. Once `tryImportOwnedRaster` succeeds, the
`RasterLease` retains its ownership: do **not** manually free it.
`lease.view()` creates a read-only borrow. `tryRoi` resolves the child
origin relative to the parent view, with no duplicate sample allocation.
The `trySample` operation reads a value copy.

The simple D loop makes the example easy to follow; the library also has
checked reduction operations for production use. Both views must remain
within the lifetime of the retained backing.

For other sample types or padded storage, describe the *actual byte strides*
rather than assuming one byte per sample. The application decides whether
these numbers represent heights, temperatures or another measurement.
`raster-d` does not automatically read GeoTIFF files or imagery services.

Continue with [Common operations](common-operations.md), the
[beginner introduction](../understanding-rasters.md) and the generated
public API reference for the exact contracts.
