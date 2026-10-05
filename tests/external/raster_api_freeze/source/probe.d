module raster_api_freeze_probe;

import core.stdc.stdlib : malloc;
import std.algorithm.mutation : move;
import raster;

static assert(isRasterSampleType!ubyte);
static assert(isRasterSampleType!float);
static assert(isRasterSampleType!(ubyte[4]));
static assert(!isRasterSampleType!(ubyte*));
static assert(!isRasterSampleType!(ubyte[]));
static assert(!isRasterSampleType!(const ubyte));

static assert(Region2D.init.empty);
static assert(Region2D.init.hasRepresentableExtent);
static assert(RasterCopyError.init == RasterCopyError.none);
static assert(UbyteToFloatConversionError.init == UbyteToFloatConversionError.none);
static assert(RasterTransformError.init == RasterTransformError.none);
static assert(RasterNeighbourhood3x3Error.init == RasterNeighbourhood3x3Error.none);
static assert(OwnedRasterResourceDisposition.init == OwnedRasterResourceDisposition.unchanged);
static assert(OwnedRasterImportError.init == OwnedRasterImportError.none);

enum ctfeRegion =
    Region2D(10, 20, 4, 3)
        .containsRelative(Region2D(1, 1, 2, 1));
static assert(ctfeRegion);

@safe pure nothrow @nogc
void regionContract()
{
    Region2D resolved;
    const region = Region2D(10, 20, 4, 3);
    assert(region.tryResolveRelative(
        relative: Region2D(1, 1, 2, 1),
        resolved: resolved
    ));
}

@safe nothrow @nogc
void inertViewContract()
{
    RasterView!ubyte view;
    assert(view.planeCount == 0);
    assert(view.region == Region2D.init);
    assert(view.width == 0);
    assert(view.height == 0);
    assert(view.empty);

    bool roiSuccess;
    scope auto roi = view.tryRoi(
        relative: Region2D.init,
        success: roiSuccess
    );
    assert(roiSuccess);

    ubyte value = 99;
    assert(!view.trySample(
        band: 0,
        x: 0,
        y: 0,
        value: value
    ));
    assert(value == ubyte.init);

    WritableRasterView!ubyte writable;
    assert(writable.planeCount == 0);
    assert(writable.empty);

    bool writableRoiSuccess;
    scope auto writableRoi = writable.tryRoi(
        relative: Region2D.init,
        success: writableRoiSuccess
    );
    assert(writableRoiSuccess);

    value = 99;
    assert(!writable.trySample(
        band: 0,
        x: 0,
        y: 0,
        value: value
    ));
    assert(value == ubyte.init);

    assert(!writable.trySetSample(
        band: 0,
        x: 0,
        y: 0,
        value: cast(ubyte) 7
    ));
}

private float plusOne(float value)
@safe pure nothrow @nogc
{
    return value + 1.0f;
}

private float center(ref const(float)[9] values)
@safe pure nothrow @nogc
{
    return values[4];
}

@safe nothrow @nogc
void operationSignatureContract()
{
    RasterView!ubyte sourceBytes;
    WritableRasterView!ubyte destinationBytes;
    RasterView!float sourceFloats;
    WritableRasterView!float destinationFloats;

    RasterCopyError copyError;
    cast(void) tryCopyRasterPlane(
        source: sourceBytes,
        sourcePlaneIndex: 0,
        destination: destinationBytes,
        destinationPlaneIndex: 0,
        error: copyError
    );

    UbyteToFloatConversionError conversionError;
    cast(void) tryConvertUbyteToFloatPlane(
        source: sourceBytes,
        sourcePlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: conversionError
    );

    cast(void) tryFillRasterPlane(
        destination: destinationBytes,
        planeIndex: 0,
        value: cast(ubyte) 0
    );

    RasterTransformError transformError;
    cast(void) tryTransformRasterPlane!plusOne(
        source: sourceFloats,
        sourcePlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: transformError
    );

    RasterNeighbourhood3x3Error neighbourhoodError;
    cast(void) tryApplyRasterNeighbourhood3x3!center(
        source: sourceFloats,
        sourcePlaneIndex: 0,
        sourceOutputRegion: Region2D.init,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: neighbourhoodError
    );

    double sum;
    cast(void) trySumFloatToDouble(
        source: sourceFloats,
        planeIndex: 0,
        result: sum
    );
}

@system nothrow @nogc
void adoptSignatureContract()
{
    OwnedByteResource owned;
    cast(void) tryAdoptMallocResource(
        base: null,
        byteLength: 0,
        owned: owned
    );
}

@safe
void importSignatureContract(
    ref OwnedByteResource resource,
    ref RasterLease!ubyte lease
)
{
    const PlaneByteLayout[1] planes =
        [PlaneByteLayout(0, 4, 1)];

    const result = tryImportOwnedRaster!ubyte(
        resource: resource,
        planes: planes[],
        residentRegion: Region2D(0, 0, 4, 1),
        lease: lease
    );

    cast(void) result.error;
    cast(void) result.planeIndex;
    cast(void) result.ok;
    cast(void) result.resourceDisposition;
}

unittest
{
    inertViewContract();

    OwnedRasterImportResult result;
    assert(!result.ok);
    assert(result.error == OwnedRasterImportError.internalConstructionFailure);
    assert(result.planeIndex == size_t.max);
    assert(result.resourceDisposition == OwnedRasterResourceDisposition.unchanged);

    OwnedByteResource resource;
    assert(!resource.ownsResource);
    assert(resource.byteLength == 0);
}

unittest
{
    void* memory = malloc(4);
    assert(memory !is null);
    auto samples = (cast(ubyte*) memory)[0 .. 4];
    samples[] = [1, 2, 3, 4];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 4, resource));

    const PlaneByteLayout[1] planes =
        [PlaneByteLayout(0, 2, 1)];

    RasterLease!ubyte lease;
    const imported = tryImportOwnedRaster!ubyte(
        resource,
        planes[],
        Region2D(0, 0, 2, 2),
        lease
    );
    assert(imported.ok);
    assert(imported.resourceDisposition == OwnedRasterResourceDisposition.transferredToLease);

    scope auto readable = lease.view();
    assert(readable.planeCount == 1);

    bool writableSuccess;
    scope auto writable = lease.tryWritableView(writableSuccess);
    assert(writableSuccess);
    assert(writable.trySetSample(0, 1, 1, 9));

    ubyte value;
    assert(readable.trySample(0, 1, 1, value));
    assert(value == 9);
}

unittest
{
    void* memory = malloc(1);
    assert(memory !is null);

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 1, resource));

    const PlaneByteLayout[1] planes =
        [PlaneByteLayout(0, 1, 1)];

    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource,
        planes[],
        Region2D(0, 0, 1, 1),
        lease
    ).ok);

    auto retainedCopy = lease;
    scope auto view = retainedCopy.view();
    assert(view.planeCount == 1);

    retainedCopy = RasterLease!ubyte.init;
}
