module raster.internal.materialization;

import raster.internal.materialization_plan :
    RequestMaterializationPlan;

import raster.region :
    Region2D;

import raster.writable_view :
    WritableRasterView;


/++
    Package-internal failure categories for synchronous caller-owned
    materialization.
+/
package(raster)
enum RequestMaterializationError : ubyte
{
    none,

    destinationRegionMismatch,

    sourceFailure
}


/++
    Materializes one planned logical input region into caller-owned resident
    storage.

    The source capability must provide:

        bool materializeInto(
            Region2D logicalRegion,
            scope WritableRasterView!T destination
        )

    The orchestration layer:

    - validates resident destination geometry;
    - forwards exactly plan.dependency.validInput;
    - performs no allocation;
    - interprets no border policy;
    - invokes no source for an empty valid-input region.

    Source-specific diagnostics remain source/adapter-owned.
+/
package(raster)
bool tryMaterializeRequest(T, Source)(
    RequestMaterializationPlan plan,
    ref Source source,
    scope WritableRasterView!T destination,
    out RequestMaterializationError error
)
@safe
{
    static assert(
        is(
            typeof(
                source.materializeInto(
                    plan.dependency.validInput,
                    destination
                )
            ) == bool
        ),
        "Materialization source must provide "
        ~ "bool materializeInto(Region2D, scope WritableRasterView!T)."
    );

    error =
        RequestMaterializationError.none;

    if (
        destination.region
        != plan.residentInput
    )
    {
        error =
            RequestMaterializationError.destinationRegionMismatch;

        return false;
    }

    if (plan.dependency.validInput.empty)
    {
        return true;
    }

    if (
        !source.materializeInto(
            plan.dependency.validInput,
            destination
        )
    )
    {
        error =
            RequestMaterializationError.sourceFailure;

        return false;
    }

    return true;
}


version (unittest)
{

import core.stdc.stdlib :
    malloc;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    RasterLease,
    tryAdoptMallocResource,
    tryImportOwnedRaster;

import raster.internal.dependency :
    ContextDeficit,
    ExpandedDependency;


private
bool makeWritableTestLease(
    size_t width,
    size_t height,
    out RasterLease!ubyte lease
)
@system
{
    lease =
        RasterLease!ubyte.init;

    if (
        width == 0
        || height == 0
        || width > cast(size_t) ptrdiff_t.max
        || height > size_t.max / width
    )
    {
        return false;
    }

    const byteLength =
        width * height;

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

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) width,
                    1
                )
            ],
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
struct RecordingSource
{
    size_t calls;

    Region2D logicalRegion;

    Region2D destinationRegion;

    bool succeed = true;


    bool materializeInto(
        Region2D region,
        scope WritableRasterView!ubyte destination
    )
    @safe
    nothrow
    @nogc
    {
        ++calls;

        logicalRegion =
            region;

        destinationRegion =
            destination.region;

        return succeed;
    }
}


unittest
{
    RasterLease!ubyte lease;

    assert(
        makeWritableTestLease(
            6,
            5,
            lease
        )
    );

    bool writableOk;

    scope auto destination =
        lease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    const plan =
        RequestMaterializationPlan(
            ExpandedDependency(
                Region2D(
                    1009,
                    2010,
                    6,
                    5
                ),
                ContextDeficit.init
            ),
            Region2D(
                0,
                0,
                6,
                5
            ),
            Region2D(
                1,
                1,
                4,
                3
            )
        );

    RecordingSource source;

    RequestMaterializationError error;

    assert(
        tryMaterializeRequest(
            plan,
            source,
            destination,
            error
        )
    );

    assert(error == RequestMaterializationError.none);
    assert(source.calls == 1);

    assert(
        source.logicalRegion
        == plan.dependency.validInput
    );

    assert(
        source.destinationRegion
        == plan.residentInput
    );
}


unittest
{
    RasterLease!ubyte lease;

    assert(
        makeWritableTestLease(
            5,
            5,
            lease
        )
    );

    bool writableOk;

    scope auto destination =
        lease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    const plan =
        RequestMaterializationPlan(
            ExpandedDependency(
                Region2D(
                    50,
                    60,
                    6,
                    5
                ),
                ContextDeficit.init
            ),
            Region2D(
                0,
                0,
                6,
                5
            ),
            Region2D.init
        );

    RecordingSource source;

    RequestMaterializationError error;

    assert(
        !tryMaterializeRequest(
            plan,
            source,
            destination,
            error
        )
    );

    assert(
        error
        == RequestMaterializationError.destinationRegionMismatch
    );

    assert(source.calls == 0);
}


unittest
{
    const plan =
        RequestMaterializationPlan(
            ExpandedDependency(
                Region2D(
                    40,
                    60,
                    0,
                    0
                ),
                ContextDeficit.init
            ),
            Region2D.init,
            Region2D.init
        );

    RecordingSource source;

    WritableRasterView!ubyte destination;

    RequestMaterializationError error;

    assert(
        tryMaterializeRequest(
            plan,
            source,
            destination,
            error
        )
    );

    assert(error == RequestMaterializationError.none);
    assert(source.calls == 0);
}


unittest
{
    RasterLease!ubyte lease;

    assert(
        makeWritableTestLease(
            4,
            3,
            lease
        )
    );

    bool writableOk;

    scope auto destination =
        lease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    const plan =
        RequestMaterializationPlan(
            ExpandedDependency(
                Region2D(
                    0,
                    0,
                    4,
                    3
                ),
                ContextDeficit(
                    1,
                    2,
                    0,
                    0
                )
            ),
            Region2D(
                0,
                0,
                4,
                3
            ),
            Region2D(
                0,
                0,
                3,
                1
            )
        );

    RecordingSource source;
    source.succeed = false;

    RequestMaterializationError error;

    assert(
        !tryMaterializeRequest(
            plan,
            source,
            destination,
            error
        )
    );

    assert(
        error
        == RequestMaterializationError.sourceFailure
    );

    assert(source.calls == 1);

    assert(
        source.logicalRegion
        == plan.dependency.validInput
    );
}

} // version (unittest)
