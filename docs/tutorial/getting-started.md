# Getting started

Not familiar with rasters, bands, strides or leases? Start with
[Understanding raster data and raster-d](../understanding-rasters.md).


`raster-d` represents raster samples without imposing image, colour, or geospatial-image semantics.

The usual starting point is an owned byte resource, a plane layout, and a logical raster region.

## Add the dependency

Use the released `raster-d` package through DUB, then import the public package:

```d
import raster;
```

## Create a small retained raster

This example adopts four bytes allocated with `malloc`, describes them as a 2 x 2 `ubyte` plane, and reads one sample.

```d
import core.stdc.stdlib : malloc;
import raster;

void main()
@system
{
    void* memory = malloc(4);
    assert(memory !is null);

    auto samples = (cast(ubyte*) memory)[0 .. 4];
    samples[] = [1, 2, 3, 4];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 4, resource));

    const PlaneByteLayout[1] layout =
    [
        PlaneByteLayout(0, 2, 1)
    ];

    RasterLease!ubyte lease;

    assert(
        tryImportOwnedRaster!ubyte(
            resource,
            layout[],
            Region2D(0, 0, 2, 2),
            lease
        ).ok
    );

    scope auto view = lease.view();

    ubyte value;
    assert(view.trySample(0, 1, 1, value));
    assert(value == 4);
}
```

After a successful import, the lease retains the adopted resource. A view borrows from that retained lifetime; it does not own the storage.

## What to learn next

Read [Common operations](../how-to/common-operations.md) for data movement and processing. Read the [Glossary](../glossary.md) if terms such as *logical region*, *plane*, *stride*, or *lease* are new.

For declaration-level contracts, use the generated Ddoc/DDox reference.
