# Generic owned RGB storage

This is the public integration contract for consumers such as `imagery-d`.
It describes storage and lifetime only. `raster-d` does not interpret JPEG,
YCbCr, chroma siting, colour matrices, ranges, clipping or normalization.

## Importing caller-owned storage

The producer first transfers one allocation to `OwnedByteResource`, then
describes each logical plane with `PlaneByteLayout`. Strides are byte strides;
they may be padded or signed. The import validates the complete reachable
footprint before publishing a lease.

```d
import core.stdc.stdlib : malloc;
import raster;

// Producer-owned, interleaved RGB float data: RGB RGB ... per row.
void* memory = malloc(width * height * 3 * float.sizeof);
OwnedByteResource resource;
assert(tryAdoptMallocResource(memory,
    width * height * 3 * float.sizeof, resource));

const PlaneByteLayout[3] planes = [
    PlaneByteLayout(0, width * 3 * float.sizeof, 3 * float.sizeof),
    PlaneByteLayout(float.sizeof, width * 3 * float.sizeof, 3 * float.sizeof),
    PlaneByteLayout(2 * float.sizeof, width * 3 * float.sizeof, 3 * float.sizeof)
];

RasterLease!float lease;
auto result = tryImportOwnedRaster!float(
    resource, planes[], Region2D(0, 0, width, height), lease);
assert(result.ok);
assert(!resource.ownsResource);
```

The same contract imports interleaved `ubyte` data by using `T == ubyte` and
byte-sized offsets/strides. Planar data uses one `PlaneByteLayout` per
component with independent offsets and row strides. `lease.view()` returns a
non-owning read-only view; `lease.tryWritableView()` is the explicit mutable
borrow and requires a mutable lease. Neither view transfers ownership.

## Failure handling

`OwnedRasterImportResult.error` distinguishes invalid plane/backing layout,
arithmetic overflow, insufficient storage and ownership misuse. On all
pre-commit failures the `OwnedByteResource` remains owned by the caller. On a
successful import ownership moves to `RasterLease` and is released exactly
once when the final lease is destroyed.

```d
auto result = tryImportOwnedRaster!float(
    resource, invalidPlanes[], Region2D(0, 0, width, height), lease);

if (!result.ok) {
    // Keep or retry the resource for pre-commit failures.
    assert(result.resourceDisposition ==
        OwnedRasterResourceDisposition.unchanged);
}
```

The public consumer surface is available through `import raster;`; consumers
must not depend on `raster.internal` or construction/validation modules.
