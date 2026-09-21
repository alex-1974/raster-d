module raster_import_link_probe;

/++
    External-consumer regression probe for retained RasterLease link closure.

    This package deliberately depends on imagery-d as a separate DUB library
    and is itself compiled with `dub test`.

    The test must therefore prove not only that the public API compiles, but
    that all retained-ownership template/destructor machinery required by an
    external consumer is present at final link time.
+/

import core.stdc.stdlib :
    malloc;

import std.algorithm.mutation :
    move;

import imagery.raster :
    OwnedByteResource,
    OwnedRasterResourceDisposition,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster;


private
RasterLease!ubyte makeImportedLease()
@system
{
    enum size_t width = 4;
    enum size_t height = 3;
    enum size_t sampleCount = width * height;

    void* memory =
        malloc(sampleCount);

    assert(memory !is null);


    auto samples =
        (cast(ubyte*) memory)
        [0 .. sampleCount];

    foreach (index, ref sample; samples)
    {
        sample =
            cast(ubyte)(
                index + 1
            );
    }


    OwnedByteResource resource;

    assert(
        tryAdoptMallocResource(
            memory,
            sampleCount,
            resource
        )
    );

    assert(resource.ownsResource);


    PlaneByteLayout[1] planes =
    [
        PlaneByteLayout(
            0,
            width,
            1
        )
    ];


    RasterLease!ubyte lease;

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            planes[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );


    assert(result.ok);

    assert(
        result.resourceDisposition
        == OwnedRasterResourceDisposition.transferredToLease
    );

    assert(!resource.ownsResource);


    return move(lease);
}


unittest
{
    auto lease =
        makeImportedLease();

    auto view =
        lease.view();

    assert(view.width == 4);
    assert(view.height == 3);
    assert(view.planeCount == 1);


    ubyte value;

    assert(
        view.trySample(
            0,
            2,
            1,
            value
        )
    );

    assert(value == 7);

    /*
     * Destruction of this externally compiled RasterLease is part of the
     * regression test. Before the backing-owner fix, final linking of this
     * unittest executable failed for both DMD and LDC because the required
     * SafeRefCounted/object.destroy instantiation was absent from imagery-d.
     */
}
