# Convert raster samples exactly

A raster might store intensity measurements as `ubyte` values (0–255),
while a numerical computation needs `float`. Converting the values does
not give them a new physical meaning; it only changes their numeric type.

For this particular conversion, every `ubyte` value is exactly
representable as an IEEE-754 binary32 `float`. The public v0.2
`convertRasterInto` operation uses an explicit `exact` policy.

## Complete example

```d
import core.stdc.stdlib : malloc;
import raster;

void main() @system
{
    void* inputMemory = malloc(4);
    void* outputMemory = malloc(4 * float.sizeof);
    assert(inputMemory !is null && outputMemory !is null);

    auto samples = (cast(ubyte*) inputMemory)[0 .. 4];
    samples[] = [0, 25, 100, 255];

    OwnedByteResource inputResource;
    OwnedByteResource outputResource;
    assert(tryAdoptMallocResource(inputMemory, 4, inputResource));
    assert(tryAdoptMallocResource(
        outputMemory, 4 * float.sizeof, outputResource
    ));

    const PlaneByteLayout[1] inputLayout = [
        PlaneByteLayout(0, 2, 1)
    ];
    const PlaneByteLayout[1] outputLayout = [
        PlaneByteLayout(0, 2 * float.sizeof, float.sizeof)
    ];

    RasterLease!ubyte inputLease;
    RasterLease!float outputLease;
    const region = Region2D(0, 0, 2, 2);

    assert(tryImportOwnedRaster!ubyte(
        inputResource, inputLayout[], region, inputLease
    ).ok);
    assert(tryImportOwnedRaster!float(
        outputResource, outputLayout[], region, outputLease
    ).ok);

    scope auto source = inputLease.view();

    bool writable;
    scope auto destination = outputLease.tryWritableView(writable);
    assert(writable);

    RasterConversionError error;
    assert(convertRasterInto!float(
        source, 0, destination, 0, error
    ));
    assert(error == RasterConversionError.none);

    scope auto result = outputLease.view();
    float value;
    assert(result.trySample(0, 1, 1, value));
    assert(value == 255.0f);
}
```

This uses two independently owned backing allocations because the source
samples and destination samples have different sizes. Both are imported
with the correct **byte** strides.

The operation takes a read-only source view and a writable destination
view. The caller retains both leases during conversion. Writing capability
does not itself establish exclusive access: applications must avoid
conflicting aliases and concurrent writes.

## When conversion fails

The checked operation reports structural problems through
`RasterConversionError`: invalid plane selection, a shape mismatch,
non-injective destination layout, or overlapping source and destination.
The `exact` policy does not silently round values to fit unsupported
sample/target pairs. Which conversions are supported is part of the
public compile-time contract.

This example performs **numeric** conversion, not colour management,
radiometric calibration or GeoTIFF decoding. Those concerns belong
in application or higher-level imagery layers.

Continue with [Common operations](common-operations.md),
[the raster introduction](../understanding-rasters.md), and the generated
public Ddoc/DDox reference.
