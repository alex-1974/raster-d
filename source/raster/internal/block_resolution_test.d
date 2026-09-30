module raster.internal.block_resolution_test;

version (unittest)
{

import core.stdc.stdlib :
    malloc;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    WritableRasterView,
    tryAdoptMallocResource,
    tryImportOwnedRaster;

import raster.internal.block_resolution :
    DependencyBlockResolveError,
    DependencyBlockResolveStats,
    RetainedBlockDescriptor,
    tryResolveDependencyBlocks;

import raster.internal.retained_store :
    RetainedRasterStore,
    RetainedStoreInsertResult;


private
struct TestKey
{
    size_t source;

    size_t generation;

    Region2D region;

    size_t schema;
}


private
size_t testHash(
    ref const TestKey key
)
@safe
pure
nothrow
@nogc
{
    size_t state =
        key.source;

    state ^=
        key.generation
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.x
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.y
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.width
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.height
        + (state << 6)
        + (state >> 2);

    state ^=
        key.schema
        + (state << 6)
        + (state >> 2);

    return state;
}


private
bool testEqual(
    ref const TestKey lhs,
    ref const TestKey rhs
)
@safe
pure
nothrow
@nogc
{
    return lhs == rhs;
}


private
ubyte sampleValue(
    size_t x,
    size_t y,
    size_t plane,
    size_t generation
)
@safe
pure
nothrow
@nogc
{
    return
        cast(ubyte)(
            cast(ubyte) x
            ^ cast(ubyte) y
            ^ cast(ubyte) (plane * 29)
            ^ cast(ubyte) generation
        );
}


private
struct TestSource
{
    size_t providerBlockWidth = 16;

    size_t providerBlockHeight = 8;

    size_t generation = 1;

    size_t planeCount = 1;

    size_t calls;

    bool failNext;

    bool wrongShapeNext;

    bool invalidLeaseNext;


    bool materializeRetained(
        Region2D logicalRegion,
        out RasterLease!ubyte lease
    )
    @system
    {
        lease =
            RasterLease!ubyte.init;

        ++calls;

        if (failNext)
        {
            failNext = false;
            return false;
        }

        if (invalidLeaseNext)
        {
            invalidLeaseNext = false;
            return true;
        }

        size_t width =
            logicalRegion.width;

        if (wrongShapeNext)
        {
            wrongShapeNext = false;
            ++width;
        }

        const rowPadding =
            cast(size_t) 3;

        if (
            planeCount == 0
            || planeCount > 2
            || width
                > (
                    size_t.max
                    - rowPadding
                ) / planeCount
        )
        {
            return false;
        }

        const rowStride =
            width * planeCount
            + rowPadding;

        if (
            logicalRegion.height != 0
            && rowStride
                > size_t.max
                    / logicalRegion.height
        )
        {
            return false;
        }

        const byteLength =
            rowStride
            * logicalRegion.height;

        if (byteLength == 0)
        {
            return false;
        }

        auto memory =
            cast(ubyte*) malloc(
                byteLength
            );

        if (memory is null)
        {
            return false;
        }

        foreach (y; 0 .. logicalRegion.height)
        {
            foreach (x; 0 .. width)
            {
                foreach (plane; 0 .. planeCount)
                {
                    memory[
                        y * rowStride
                        + x * planeCount
                        + plane
                    ] =
                        sampleValue(
                            logicalRegion.x + x,
                            logicalRegion.y + y,
                            plane,
                            generation
                        );
                }
            }
        }

        OwnedByteResource resource;

        if (
            !tryAdoptMallocResource(
                memory,
                byteLength,
                resource
            )
        )
        {
            return false;
        }

        PlaneByteLayout[2] layouts;

        foreach (plane; 0 .. planeCount)
        {
            layouts[plane] =
                PlaneByteLayout(
                    plane,
                    cast(ptrdiff_t) rowStride,
                    cast(ptrdiff_t) planeCount
                );
        }

        const result =
            tryImportOwnedRaster!ubyte(
                resource,
                layouts[0 .. planeCount],
                Region2D(
                    0,
                    0,
                    width,
                    logicalRegion.height
                ),
                lease
            );

        return result.ok;
    }
}


private
bool makeDestination(
    size_t width,
    size_t height,
    size_t planeCount,
    out RasterLease!ubyte lease
)
@system
{
    lease =
        RasterLease!ubyte.init;

    if (
        width == 0
        || height == 0
        || planeCount == 0
        || planeCount > 2
        || width
            > size_t.max / planeCount
    )
    {
        return false;
    }

    const rowStride =
        width * planeCount;

    if (
        height
        > size_t.max / rowStride
    )
    {
        return false;
    }

    const byteLength =
        rowStride * height;

    auto memory =
        malloc(byteLength);

    if (memory is null)
    {
        return false;
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            byteLength,
            resource
        )
    )
    {
        return false;
    }

    PlaneByteLayout[2] layouts;

    foreach (plane; 0 .. planeCount)
    {
        layouts[plane] =
            PlaneByteLayout(
                plane,
                cast(ptrdiff_t) rowStride,
                cast(ptrdiff_t) planeCount
            );
    }

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            layouts[0 .. planeCount],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    return result.ok;
}


private
bool verifyDestination(
    ref RasterLease!ubyte lease,
    Region2D logicalRegion,
    size_t planeCount,
    size_t generation
)
@safe
{
    auto view =
        lease.view();

    if (
        view.width != logicalRegion.width
        || view.height != logicalRegion.height
        || view.planeCount != planeCount
    )
    {
        return false;
    }

    foreach (plane; 0 .. planeCount)
    {
        foreach (y; 0 .. logicalRegion.height)
        {
            foreach (x; 0 .. logicalRegion.width)
            {
                ubyte actual;

                if (
                    !view.trySample(
                        plane,
                        x,
                        y,
                        actual
                    )
                )
                {
                    return false;
                }

                if (
                    actual
                    != sampleValue(
                        logicalRegion.x + x,
                        logicalRegion.y + y,
                        plane,
                        generation
                    )
                )
                {
                    return false;
                }
            }
        }
    }

    return true;
}


private
TestKey makeKey(
    Region2D region,
    size_t generation = 1,
    size_t schema = 1
)
@safe
pure
nothrow
@nogc
{
    return
        TestKey(
            42,
            generation,
            region,
            schema
        );
}


private
RetainedBlockDescriptor!TestKey block(
    Region2D region,
    size_t generation = 1,
    size_t schema = 1
)
@safe
pure
nothrow
@nogc
{
    return
        RetainedBlockDescriptor!TestKey(
            makeKey(
                region,
                generation,
                schema
            ),
            region
        );
}


private
alias Store16 =
    RetainedRasterStore!(
        ubyte,
        TestKey,
        16,
        testHash,
        testEqual
    );


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;

    const request =
        Region2D(
            13,
            11,
            23,
            13
        );

    RetainedBlockDescriptor!TestKey[4] blocks =
    [
        block(Region2D(12, 10, 12, 10)),
        block(Region2D(24, 10, 12, 10)),
        block(Region2D(12, 20, 12, 10)),
        block(Region2D(24, 20, 12, 10))
    ];

    RasterLease!ubyte destinationLease;

    assert(
        makeDestination(
            request.width,
            request.height,
            1,
            destinationLease
        )
    );

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.none);
    assert(stats.retainedHits == 0);
    assert(stats.sourceMisses == 4);
    assert(stats.storeInsertions == 4);
    assert(stats.storeInsertionRejections == 0);
    assert(source.calls == 4);

    assert(
        verifyDestination(
            destinationLease,
            request,
            1,
            1
        )
    );

    assert(source.providerBlockWidth == 16);
    assert(source.providerBlockHeight == 8);
    assert(blocks[0].logicalRegion.width == 12);
    assert(blocks[0].logicalRegion.height == 10);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;

    const firstRequest =
        Region2D(
            13,
            11,
            23,
            13
        );

    RetainedBlockDescriptor!TestKey[4] firstBlocks =
    [
        block(Region2D(12, 10, 12, 10)),
        block(Region2D(24, 10, 12, 10)),
        block(Region2D(12, 20, 12, 10)),
        block(Region2D(24, 20, 12, 10))
    ];

    RasterLease!ubyte firstLease;

    assert(
        makeDestination(
            firstRequest.width,
            firstRequest.height,
            1,
            firstLease
        )
    );

    bool firstWritableOk;

    scope auto firstDestination =
        firstLease.tryWritableView(
            firstWritableOk
        );

    assert(firstWritableOk);

    DependencyBlockResolveStats firstStats;
    DependencyBlockResolveError firstError;

    assert(
        tryResolveDependencyBlocks(
            firstRequest,
            firstBlocks[],
            store,
            source,
            firstDestination,
            firstStats,
            firstError
        )
    );

    assert(source.calls == 4);

    const secondRequest =
        Region2D(
            20,
            16,
            21,
            11
        );

    RetainedBlockDescriptor!TestKey[6] secondBlocks =
    [
        block(Region2D(12, 10, 12, 10)),
        block(Region2D(24, 10, 12, 10)),
        block(Region2D(36, 10, 12, 10)),
        block(Region2D(12, 20, 12, 10)),
        block(Region2D(24, 20, 12, 10)),
        block(Region2D(36, 20, 12, 10))
    ];

    RasterLease!ubyte secondLease;

    assert(
        makeDestination(
            secondRequest.width,
            secondRequest.height,
            1,
            secondLease
        )
    );

    bool secondWritableOk;

    scope auto secondDestination =
        secondLease.tryWritableView(
            secondWritableOk
        );

    assert(secondWritableOk);

    DependencyBlockResolveStats secondStats;
    DependencyBlockResolveError secondError;

    assert(
        tryResolveDependencyBlocks(
            secondRequest,
            secondBlocks[],
            store,
            source,
            secondDestination,
            secondStats,
            secondError
        )
    );

    assert(secondStats.retainedHits == 4);
    assert(secondStats.sourceMisses == 2);
    assert(secondStats.storeInsertions == 2);
    assert(source.calls == 6);

    assert(
        verifyDestination(
            secondLease,
            secondRequest,
            1,
            1
        )
    );

    RasterLease!ubyte thirdLease;

    assert(
        makeDestination(
            secondRequest.width,
            secondRequest.height,
            1,
            thirdLease
        )
    );

    bool thirdWritableOk;

    scope auto thirdDestination =
        thirdLease.tryWritableView(
            thirdWritableOk
        );

    assert(thirdWritableOk);

    DependencyBlockResolveStats thirdStats;
    DependencyBlockResolveError thirdError;

    assert(
        tryResolveDependencyBlocks(
            secondRequest,
            secondBlocks[],
            store,
            source,
            thirdDestination,
            thirdStats,
            thirdError
        )
    );

    assert(thirdStats.retainedHits == 6);
    assert(thirdStats.sourceMisses == 0);
    assert(source.calls == 6);
}


unittest
{
    alias TinyByteStore =
        RetainedRasterStore!(
            ubyte,
            TestKey,
            4,
            testHash,
            testEqual
        );

    TinyByteStore store =
        TinyByteStore(1);

    TestSource source;

    const request =
        Region2D(
            100,
            200,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(4, 4, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(stats.sourceMisses == 1);
    assert(stats.storeInsertions == 0);
    assert(stats.storeInsertionRejections == 1);
    assert(store.entryCount == 0);

    assert(
        verifyDestination(
            destinationLease,
            request,
            1,
            1
        )
    );
}


unittest
{
    alias OneEntryStore =
        RetainedRasterStore!(
            ubyte,
            TestKey,
            1,
            testHash,
            testEqual
        );

    OneEntryStore store =
        OneEntryStore(10_000);

    TestSource source;

    const primingRegion =
        Region2D(
            0,
            0,
            4,
            4
        );

    RasterLease!ubyte primingLease;

    assert(
        source.materializeRetained(
            primingRegion,
            primingLease
        )
    );

    auto primingKey =
        makeKey(primingRegion);

    assert(
        store.insertOwned(
            primingKey,
            primingLease
        )
        == RetainedStoreInsertResult.inserted
    );

    const request =
        Region2D(
            10,
            10,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(4, 4, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(stats.sourceMisses == 1);
    assert(stats.storeInsertionRejections == 1);
    assert(store.entryCount == 1);

    assert(
        verifyDestination(
            destinationLease,
            request,
            1,
            1
        )
    );
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;

    const request =
        Region2D(
            size_t.max - 100,
            size_t.max - 200,
            20,
            12
        );

    RetainedBlockDescriptor!TestKey[2] blocks =
    [
        block(
            Region2D(
                size_t.max - 105,
                size_t.max - 205,
                15,
                22
            )
        ),
        block(
            Region2D(
                size_t.max - 90,
                size_t.max - 205,
                15,
                22
            )
        )
    ];

    RasterLease!ubyte destinationLease;

    assert(
        makeDestination(
            request.width,
            request.height,
            1,
            destinationLease
        )
    );

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(
        verifyDestination(
            destinationLease,
            request,
            1,
            1
        )
    );
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;
    source.planeCount = 2;

    const request =
        Region2D(
            30,
            40,
            8,
            6
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request, 1, 2)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(8, 6, 2, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(
        verifyDestination(
            destinationLease,
            request,
            2,
            1
        )
    );
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;

    const request =
        Region2D(
            0,
            0,
            8,
            8
        );

    RetainedBlockDescriptor!TestKey[2] overlapBlocks =
    [
        block(Region2D(0, 0, 5, 8)),
        block(Region2D(4, 0, 4, 8))
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(8, 8, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        !tryResolveDependencyBlocks(
            request,
            overlapBlocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.invalidCoverage);
    assert(source.calls == 0);

    RetainedBlockDescriptor!TestKey[2] gapBlocks =
    [
        block(Region2D(0, 0, 3, 8)),
        block(Region2D(4, 0, 4, 8))
    ];

    assert(
        !tryResolveDependencyBlocks(
            request,
            gapBlocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.invalidCoverage);
    assert(source.calls == 0);

    RetainedBlockDescriptor!TestKey[1] invalidBlocks =
    [
        block(
            Region2D(
                size_t.max,
                0,
                1,
                1
            )
        )
    ];

    assert(
        !tryResolveDependencyBlocks(
            request,
            invalidBlocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.invalidCoverage);
    assert(source.calls == 0);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;

    const request =
        Region2D(
            10,
            20,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte wrongDestinationLease;

    assert(makeDestination(3, 4, 1, wrongDestinationLease));

    bool writableOk;

    scope auto destination =
        wrongDestinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        !tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(
        error
        == DependencyBlockResolveError.destinationRegionMismatch
    );

    assert(source.calls == 0);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;
    source.failNext = true;

    const request =
        Region2D(
            10,
            20,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(4, 4, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        !tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.sourceFailure);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;
    source.invalidLeaseNext = true;

    const request =
        Region2D(
            10,
            20,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(4, 4, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        !tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.invalidRetainedValue);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;
    source.wrongShapeNext = true;

    const request =
        Region2D(
            10,
            20,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(4, 4, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        !tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.blockShapeMismatch);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;
    source.planeCount = 2;

    const request =
        Region2D(
            10,
            20,
            4,
            4
        );

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(request)
    ];

    RasterLease!ubyte destinationLease;

    assert(makeDestination(4, 4, 1, destinationLease));

    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        !tryResolveDependencyBlocks(
            request,
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.planeCountMismatch);
}


unittest
{
    Store16 store =
        Store16(10_000);

    TestSource source;

    RetainedBlockDescriptor!TestKey[1] blocks =
    [
        block(
            Region2D(
                size_t.max,
                size_t.max,
                0,
                0
            )
        )
    ];

    WritableRasterView!ubyte destination;

    DependencyBlockResolveStats stats;
    DependencyBlockResolveError error;

    assert(
        tryResolveDependencyBlocks(
            Region2D(
                size_t.max,
                size_t.max,
                0,
                0
            ),
            blocks[],
            store,
            source,
            destination,
            stats,
            error
        )
    );

    assert(error == DependencyBlockResolveError.none);
    assert(source.calls == 0);
    assert(stats == DependencyBlockResolveStats.init);
}

} // version (unittest)
