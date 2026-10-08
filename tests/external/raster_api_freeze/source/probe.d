module raster_api_freeze_probe;

import core.stdc.stdlib : malloc;
import std.algorithm.mutation : move;
import raster;

/*
 * v0.2 aggregate-root inventory and source contract.
 *
 * This probe deliberately imports only `raster`. The supported compatibility
 * surface is the set re-exported by source/raster/package.d.
 */

static assert(isRasterSampleType!ubyte);
static assert(isRasterSampleType!float);
static assert(isRasterSampleType!(ubyte[4]));
static assert(!isRasterSampleType!(ubyte*));
static assert(!isRasterSampleType!(ubyte[]));
static assert(!isRasterSampleType!(const ubyte));

static assert(isNumericRasterSample!ubyte);
static assert(isNumericRasterSample!float);
static assert(!isNumericRasterSample!(ubyte[4]));

static assert(isExactConvertible!(ubyte, float));
static assert(isExactConvertible!(float, double));
static assert(!isExactConvertible!(double, float));

static assert(is(OwnedByteResource));
static assert(is(PlaneByteLayout));
static assert(is(PlaneDescriptor));
static assert(is(Region2D));
static assert(is(OwnedRasterImportResult));
static assert(is(RasterLease!ubyte));
static assert(is(RasterView!ubyte));
static assert(is(WritableRasterView!ubyte));

static assert(is(RasterSumResult!double));
static assert(is(RasterMeanResult!double));
static assert(is(RasterExtremaResult!float));
static assert(is(RasterMinMaxResult!float));

static assert(is(RasterAllocatedTransformResult!float));
static assert(is(RasterAllocatedConversionResult!float));

alias Shape3x3 = NeighbourhoodShape!(3, 3, 1, 1);
static assert(Shape3x3.width == 3);
static assert(Shape3x3.height == 3);
static assert(Shape3x3.anchorX == 1);
static assert(Shape3x3.anchorY == 1);
static assert(Shape3x3.left == 1);
static assert(Shape3x3.right == 1);
static assert(Shape3x3.top == 1);
static assert(Shape3x3.bottom == 1);
static assert(Shape3x3.sampleCount == 9);
static assert(Shape3x3.tupleof.length == 0);

alias IdentityKernel = FixedConvolutionKernel!(
    Shape3x3,
    float,
    0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f
);
static assert(IdentityKernel.shape.sampleCount == 9);
static assert(IdentityKernel.coefficientType.sizeof == float.sizeof);
static assert(IdentityKernel.coefficients[4] == 1.0f);
static assert(IdentityKernel.tupleof.length == 0);

static assert(RasterBorderKind.init == RasterBorderKind.valid);
static assert(RasterValidBorder.kind == RasterBorderKind.valid);
static assert(RasterClampBorder.kind == RasterBorderKind.clamp);
static assert(RasterMirrorBorder.kind == RasterBorderKind.mirror);
static assert(RasterWrapBorder.kind == RasterBorderKind.wrap);
static assert(RasterConstantBorder!ubyte.kind == RasterBorderKind.constant);

static assert(Region2D.init.empty);
static assert(Region2D.init.hasRepresentableExtent);

static assert(RasterCopyError.init == RasterCopyError.none);
static assert(UbyteToFloatConversionError.init == UbyteToFloatConversionError.none);
static assert(RasterConversionError.init == RasterConversionError.none);
static assert(RasterConversionPolicy.init == RasterConversionPolicy.exact);
static assert(RasterTransformError.init == RasterTransformError.none);
static assert(RasterZipTransformError.init == RasterZipTransformError.none);
static assert(RasterNeighbourhood3x3Error.init == RasterNeighbourhood3x3Error.none);
static assert(RasterNeighbourhoodError.init == RasterNeighbourhoodError.none);
static assert(RasterSumError.init == RasterSumError.none);
static assert(RasterMeanError.init == RasterMeanError.none);
static assert(RasterExtremaError.init == RasterExtremaError.none);
static assert(RasterAllocatedTransformError.init == RasterAllocatedTransformError.none);
static assert(RasterAllocatedConversionError.init == RasterAllocatedConversionError.none);
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

    assert(resolved == Region2D(11, 21, 2, 1));
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
    assert(writable.region == Region2D.init);
    assert(writable.width == 0);
    assert(writable.height == 0);
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

private float addFloat(float left, float right)
@safe pure nothrow @nogc
{
    return left + right;
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
    cast(void) copyInto(
        source: sourceBytes,
        sourcePlaneIndex: 0,
        destination: destinationBytes,
        destinationPlaneIndex: 0,
        error: copyError
    );

    cast(void) tryFillRasterPlane(
        destination: destinationBytes,
        planeIndex: 0,
        value: cast(ubyte) 0
    );
    cast(void) fill(
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
    cast(void) transformInto!plusOne(
        source: sourceFloats,
        sourcePlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: transformError
    );

    RasterZipTransformError zipError;
    cast(void) zipTransformInto!addFloat(
        left: sourceFloats,
        leftPlaneIndex: 0,
        right: sourceFloats,
        rightPlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: zipError
    );
    cast(void) addInto(
        left: sourceFloats,
        leftPlaneIndex: 0,
        right: sourceFloats,
        rightPlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: zipError
    );
    cast(void) subtractInto(
        left: sourceFloats,
        leftPlaneIndex: 0,
        right: sourceFloats,
        rightPlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: zipError
    );
    cast(void) multiplyInto(
        left: sourceFloats,
        leftPlaneIndex: 0,
        right: sourceFloats,
        rightPlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: zipError
    );
    cast(void) divideInto(
        left: sourceFloats,
        leftPlaneIndex: 0,
        right: sourceFloats,
        rightPlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: zipError
    );

    UbyteToFloatConversionError legacyConversionError;
    cast(void) tryConvertUbyteToFloatPlane(
        source: sourceBytes,
        sourcePlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: legacyConversionError
    );

    RasterConversionError conversionError;
    cast(void) convertRasterInto!float(
        source: sourceBytes,
        sourcePlaneIndex: 0,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: conversionError
    );

    const sumResult = sum!double(
        source: sourceFloats,
        planeIndex: 0
    );
    cast(void) sumResult.ok;
    cast(void) sumResult.error;
    cast(void) sumResult.value;

    const meanResult = mean!(double, double)(
        source: sourceFloats,
        planeIndex: 0
    );
    cast(void) meanResult.ok;
    cast(void) meanResult.error;
    cast(void) meanResult.value;

    const minimum = min(
        source: sourceFloats,
        planeIndex: 0
    );
    const maximum = max(
        source: sourceFloats,
        planeIndex: 0
    );
    const extrema = minMax(
        source: sourceFloats,
        planeIndex: 0
    );
    cast(void) minimum.value;
    cast(void) maximum.value;
    cast(void) extrema.minimum;
    cast(void) extrema.maximum;

    double strictSum;
    cast(void) trySumFloatToDouble(
        source: sourceFloats,
        planeIndex: 0,
        sum: strictSum
    );

    RasterNeighbourhood3x3Error neighbourhood3x3Error;
    cast(void) tryApplyRasterNeighbourhood3x3!center(
        source: sourceFloats,
        sourcePlaneIndex: 0,
        sourceOutputRegion: Region2D.init,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: neighbourhood3x3Error
    );

    RasterNeighbourhoodError neighbourhoodError;
    cast(void) applyNeighbourhoodInto!(Shape3x3, center)(
        source: sourceFloats,
        sourcePlaneIndex: 0,
        sourceOutputRegion: Region2D.init,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: neighbourhoodError
    );

    cast(void) convolveInto!(IdentityKernel, float)(
        source: sourceFloats,
        sourcePlaneIndex: 0,
        sourceOutputRegion: Region2D.init,
        destination: destinationFloats,
        destinationPlaneIndex: 0,
        error: neighbourhoodError
    );
}

@safe
void allocatingSignatureContract()
{
    RasterView!float sourceFloats;
    RasterView!ubyte sourceBytes;

    auto transformed = tryTransformAllocated!plusOne(
        source: sourceFloats,
        sourcePlaneIndex: 0
    );
    assert(!transformed.ok);
    assert(
        transformed.error
        == RasterAllocatedTransformError.invalidSourcePlane
    );
    assert(transformed.transformError == RasterTransformError.none);
    assert(transformed.lease().view().empty);

    auto converted = tryConvertAllocated!float(
        source: sourceBytes,
        sourcePlaneIndex: 0
    );
    assert(!converted.ok);
    assert(
        converted.error
        == RasterAllocatedConversionError.invalidSourcePlane
    );
    assert(converted.conversionError == RasterConversionError.none);
    assert(converted.lease().view().empty);
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
    regionContract();
    inertViewContract();
    operationSignatureContract();
    allocatingSignatureContract();

    RasterConstantBorder!ubyte constant =
        RasterConstantBorder!ubyte(17);
    assert(constant.value == 17);

    RasterSumResult!double sumResult;
    assert(!sumResult.ok);
    assert(sumResult.error == RasterSumError.invalidPlane);
    assert(sumResult.value == 0.0);

    RasterMeanResult!double meanResult;
    assert(!meanResult.ok);
    assert(meanResult.error == RasterMeanError.invalidPlane);
    assert(meanResult.value == 0.0);

    RasterExtremaResult!float extremaResult;
    assert(!extremaResult.ok);
    assert(extremaResult.error == RasterExtremaError.invalidPlane);

    RasterMinMaxResult!float minMaxResult;
    assert(!minMaxResult.ok);
    assert(minMaxResult.error == RasterExtremaError.invalidPlane);

    RasterAllocatedTransformResult!float transformResult;
    assert(!transformResult.ok);
    assert(
        transformResult.error
        == RasterAllocatedTransformError.internalFailure
    );

    RasterAllocatedConversionResult!float conversionResult;
    assert(!conversionResult.ok);
    assert(
        conversionResult.error
        == RasterAllocatedConversionError.internalFailure
    );

    // RasterLease.init is a valid inert lifetime capability.
    RasterLease!ubyte emptyLease;
    scope auto emptyView = emptyLease.view();
    assert(emptyView.planeCount == 0);
    assert(emptyView.empty);

    bool writableSuccess;
    scope auto emptyWritable = emptyLease.tryWritableView(
        success: writableSuccess
    );
    assert(!writableSuccess);
    assert(emptyWritable.empty);

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
    assert(
        imported.resourceDisposition
        == OwnedRasterResourceDisposition.transferredToLease
    );

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
