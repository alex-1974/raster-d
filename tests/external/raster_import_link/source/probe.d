module raster_import_link_probe;

/++
    External-consumer regression probe for retained RasterLease link closure.

    This package deliberately depends on raster-d as a separate DUB library
    and is itself compiled with `dub test`.

    The test must therefore prove not only that the public API compiles, but
    that all retained-ownership template/destructor machinery required by an
    external consumer is present at final link time.
+/

import core.stdc.stdlib :
    malloc;

import std.algorithm.mutation :
    move;

import raster :
    OwnedByteResource,
    OwnedRasterResourceDisposition,
    PlaneByteLayout,
    RasterLease,
    RasterPlaneWindow,
    WritableRasterView,
    WritableRasterPlaneWindow,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster,
    withContiguousPlane,
    withPlane,
    withPlanesInto;


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

    size_t visited;
    ubyte total;
    assert(
        withContiguousPlane(
            view,
            0,
            (scope const(ubyte)[] samples, size_t callbackWidth, size_t callbackHeight)
            @safe nothrow @nogc
            {
                assert(callbackWidth == 4);
                assert(callbackHeight == 3);
                visited = samples.length;
                foreach (sample; samples)
                    total += sample;
            }
        )
    );
    assert(visited == 12);
    assert(total == 78);

    size_t affineCount;
    assert(
        withPlane(
            view,
            0,
            (scope ref const(RasterPlaneWindow!ubyte) window)
            @safe nothrow @nogc
            {
                assert(window.width == 4);
                assert(window.height == 3);
                assert(window.sampleStride == 1);
                assert(window.rowStride == 4);
                assert(window.load(2, 1) == 7);
                affineCount++;
            }
        )
    );
    assert(affineCount == 1);

    WritableRasterView!float emptyDestination;
    RasterPlaneWindow!ubyte[1] sourceWindows;
    WritableRasterPlaneWindow!float[1] destinationWindows;
    assert(!withPlanesInto(
        view,
        [0],
        emptyDestination,
        [0],
        sourceWindows[],
        destinationWindows[],
        (scope const(RasterPlaneWindow!ubyte)[] sources,
            scope WritableRasterPlaneWindow!float[] destinations)
            @safe nothrow @nogc
            {
                assert(sources.length == 1);
                assert(destinations.length == 1);
            }
    ));

    RasterPlaneWindow!ubyte[] noSourceWindows;
    assert(!withPlanesInto(
        view,
        [0],
        emptyDestination,
        [0],
        noSourceWindows,
        destinationWindows[],
        null
    ));

    RasterPlaneWindow!ubyte[1] invalidSourceWindows;
    assert(!withPlanesInto(
        view,
        [99],
        emptyDestination,
        [0],
        invalidSourceWindows[],
        destinationWindows[],
        null
    ));

    bool sameWritableSuccess;
    scope auto sameWritable = lease.tryWritableView(sameWritableSuccess);
    assert(sameWritableSuccess);
    RasterPlaneWindow!ubyte[1] sameSources;
    WritableRasterPlaneWindow!ubyte[1] sameDestinations;
    assert(!withPlanesInto(
        view,
        [0],
        sameWritable,
        [0],
        sameSources[],
        sameDestinations[],
        null
    ));

    /*
     * Destruction of this externally compiled RasterLease is part of the
     * regression test. Before the backing-owner fix, final linking of this
     * unittest executable failed for both DMD and LDC because the required
     * SafeRefCounted/object.destroy instantiation was absent from raster-d.
     */
}

unittest
{
    // A 2x3 plane whose logical rows traverse physical storage backwards.
    void* memory = malloc(6);
    assert(memory !is null);
    auto samples = (cast(ubyte*) memory)[0 .. 6];
    samples[] = [1, 2, 3, 4, 5, 6];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 6, resource));

    const PlaneByteLayout[1] planes =
        [PlaneByteLayout(4, -2, 1)];

    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource, planes[], Region2D(0, 0, 2, 3), lease).ok);

    bool writableSuccess;
    scope auto writable = lease.tryWritableView(writableSuccess);
    assert(writableSuccess);

    assert(withPlane(
        writable,
        0,
        (scope ref WritableRasterPlaneWindow!ubyte window)
            @safe nothrow @nogc
            {
                assert(window.rowStride == -2);
                assert(window.sampleStride == 1);
                assert(window.load(0, 0) == 5);
                window.store(1, 0, 60);
                window.store(0, 2, 70);
            }
    ));

    ubyte value;
    auto readable = lease.view();
    assert(readable.trySample(0, 1, 0, value));
    assert(value == 60);
    assert(readable.trySample(0, 0, 2, value));
    assert(value == 70);
}

unittest
{
    // Two interleaved 2x2 planes: [p0,p1,p0,p1] per row.
    void* memory = malloc(8);
    assert(memory !is null);
    auto samples = (cast(ubyte*) memory)[0 .. 8];
    samples[] = [10, 20, 11, 21, 12, 22, 13, 23];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 8, resource));
    const PlaneByteLayout[2] planes =
        [PlaneByteLayout(0, 4, 2), PlaneByteLayout(1, 4, 2)];

    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource, planes[], Region2D(0, 0, 2, 2), lease).ok);

    bool writableSuccess;
    scope auto writable = lease.tryWritableView(writableSuccess);
    assert(writableSuccess);

    assert(withPlane(
        writable,
        1,
        (scope ref WritableRasterPlaneWindow!ubyte window)
            @safe nothrow @nogc
            {
                assert(window.rowStride == 4);
                assert(window.sampleStride == 2);
                assert(window.load(1, 0) == 21);
                window.store(0, 1, 220);
            }
    ));

    auto readable = lease.view();
    ubyte value;
    assert(readable.trySample(1, 0, 1, value));
    assert(value == 220);
    assert(readable.trySample(0, 1, 1, value));
    assert(value == 13);
}

unittest
{
    // Three planar ubyte channels -> three planar float channels.
    void* sourceMemory = malloc(6);
    assert(sourceMemory !is null);
    auto sourceSamples = (cast(ubyte*) sourceMemory)[0 .. 6];
    sourceSamples[] = [10, 11, 20, 21, 30, 31];

    OwnedByteResource sourceResource;
    assert(tryAdoptMallocResource(sourceMemory, 6, sourceResource));
    const PlaneByteLayout[3] sourceLayouts =
        [PlaneByteLayout(0, 2, 1), PlaneByteLayout(2, 2, 1), PlaneByteLayout(4, 2, 1)];

    RasterLease!ubyte sourceLease;
    assert(tryImportOwnedRaster!ubyte(
        sourceResource, sourceLayouts[], Region2D(0, 0, 2, 1), sourceLease).ok);
    scope auto sourceView = sourceLease.view();

    void* destinationMemory = malloc(24);
    assert(destinationMemory !is null);
    auto destinationSamples = (cast(float*) destinationMemory)[0 .. 6];
    destinationSamples[] = 0.0f;

    OwnedByteResource destinationResource;
    assert(tryAdoptMallocResource(destinationMemory, 24, destinationResource));
    const PlaneByteLayout[3] destinationLayouts =
        [PlaneByteLayout(0, 8, 4), PlaneByteLayout(8, 8, 4), PlaneByteLayout(16, 8, 4)];

    RasterLease!float destinationLease;
    assert(tryImportOwnedRaster!float(
        destinationResource, destinationLayouts[], Region2D(0, 0, 2, 1), destinationLease).ok);
    bool writableSuccess;
    scope auto destinationView = destinationLease.tryWritableView(writableSuccess);
    assert(writableSuccess);

    RasterPlaneWindow!ubyte[3] sourceWindows;
    WritableRasterPlaneWindow!float[3] destinationWindows;
    assert(withPlanesInto(
        sourceView,
        [0, 1, 2],
        destinationView,
        [0, 1, 2],
        sourceWindows[],
        destinationWindows[],
        (scope const(RasterPlaneWindow!ubyte)[] sources,
            scope WritableRasterPlaneWindow!float[] destinations)
            @safe nothrow @nogc
            {
                foreach (channel; 0 .. 3)
                    foreach (x; 0 .. 2)
                        destinations[channel].store(x, 0,
                            cast(float) sources[channel].load(x, 0) + 0.5f);
            }
    ));

    auto result = destinationLease.view();
    float value;
    assert(result.trySample(0, 0, 0, value) && value == 10.5f);
    assert(result.trySample(1, 1, 0, value) && value == 21.5f);
    assert(result.trySample(2, 0, 0, value) && value == 30.5f);
}
