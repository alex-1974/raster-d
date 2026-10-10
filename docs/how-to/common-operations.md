# Common operations

Start with [Inspect a raster region without copying](inspect-roi.md) for a complete, beginner-friendly public-API example.

Most raster-d operations use caller-owned source and destination storage. They report failure explicitly and do not hide worker threads.

## Copy one plane

Use `tryCopyRasterPlane` when source and destination have the same sample type.

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

The fixed convolution family uses a compile-time kernel and a caller-selected output region.

The caller supplies the destination. Border synthesis is not hidden inside the operation; the requested source context must be valid for the chosen output region.

## Keep scheduling outside the library

The public API performs no hidden parallel scheduling. If an application wants parallel work, it should divide independent regions or requests at a higher layer and keep worker-count, affinity, queueing, and cancellation policy there.

See the generated API reference for exact signatures and failure enums.
