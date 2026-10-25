# Common operations

Start with [Inspect a raster region without copying](inspect-roi.md) for a complete, beginner-friendly public-API example.

Most raster-d operations use caller-owned source and destination storage. They report failure explicitly and do not hide worker threads.

## Copy one plane

Use `tryCopyRasterPlane` when source and destination have the same sample type.
For the corresponding v0.2 destination-oriented spelling, see `copyInto`
in the [frozen API contract](../API_0_2.md).

The operation checks shape, writable backing, overlap, and address representability before it writes. The exact overlap contract is part of the public Ddoc.

## Convert samples

For a complete `ubyte` to `float` example with checked results, see
[Convert raster samples exactly](convert-samples.md).

Use the generic conversion family for supported sample conversions. The released 0.1 API also includes exact `ubyte -> float` conversion.

Keep source and destination lifetimes visible in the calling scope:

```d
scope auto source = sourceLease.view();

bool writable;
scope auto destination = destinationLease.tryWritableView(writable);
assert(writable);
```

Then call the conversion operation and check its explicit success/error channel.

## Transform samples

Point transforms are selected at compile time. A transform should express only the per-sample operation; raster-d owns the layout validation and execution dispatch.

Prefer destination-oriented operations when the caller already controls output storage.

## Reduce a plane

For a complete example with `sum!ulong`, result checking and ownership,
see [Sum the values of a raster plane](sum-raster.md).

`trySumFloatToDouble` uses strict logical row-major accumulation into one `double` accumulator.

That order is part of the numerical contract. An implementation may specialize layout or compiler code generation internally, but it may not reassociate the reduction.

## Apply a fixed convolution

For a visual explanation of the 3 × 3 window, halo and edge conditions,
read [Neighbourhoods and fixed convolution](neighbourhood-convolution.md).

The fixed convolution family uses a compile-time kernel and a caller-selected output region.

The caller supplies the destination. Border synthesis is not hidden inside the operation; the requested source context must be valid for the chosen output region.

## Opt-in parallel row kernels

Normal raster operations remain synchronous and do not create worker threads.
For pointwise work over independent rows, callers may opt in to a bounded
local execution with `withPlanesIntoParallel`:

```d
RasterPlaneWindow!ubyte[1] sources;
WritableRasterPlaneWindow!float[1] destinations;

const success = withPlanesIntoParallel(
    source, [0], destination, [0],
    sources[], destinations[], 4, 32,
    (scope const(RasterPlaneWindow!ubyte)[] src,
        scope WritableRasterPlaneWindow!float[] dst,
        size_t firstRow, size_t endRow)
    {
        foreach (y; firstRow .. endRow)
            foreach (x; 0 .. src[0].width)
                dst[0].store(x, y, cast(float) src[0].load(x, y));
        return true;
    });
```

The worker limit and minimum chunk size are caller choices. Threads are owned
only by this invocation, all work is joined before return, and no process-wide
pool is installed. The callback may write only its assigned rows. A `false`
result means that the operation failed; already-started callbacks may have
partially written the destination, so callers should publish temporary output
only after success. Queueing, affinity, cancellation, and persistent worker
reuse remain application-layer responsibilities.

For precise signatures, failure enums and guarantees, consult the
[public v0.2 API contract](../API_0_2.md) and generated DDox reference.
The [accuracy guide](../accuracy-and-validation.md) explains why execution
order and checked conversion policies matter.
