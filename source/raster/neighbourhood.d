/++
    Public fixed 3 x 3 raster neighbourhood operation.

    M2.3 exposes one semantic radius-one neighbourhood primitive over an
    already-materialized resident source. Logical dependency derivation,
    ContextDeficit interpretation, border policy, execution specialization and
    scheduling remain outside this public contract.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-05
+/
module raster.neighbourhood;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective;

import raster.internal.validated_affine_relation :
    classifyValidatedSameTypeAffine2DRectanglesByteOverlap;

import raster.internal.neighbourhood_dispatch :
    executeApprovedNeighbourhood3x3;

import raster.region : Region2D;
import raster.view : RasterView;
import raster.writable_view : WritableRasterView;


/++
    Semantic failure category for one fixed 3 x 3 neighbourhood operation.
+/
enum RasterNeighbourhood3x3Error : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    destinationShapeMismatch,
    unsatisfiedNeighbourhood,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

/// Example using the fixed-neighbourhood error category.
@safe unittest
{
    import raster;
    assert(RasterNeighbourhood3x3Error.init == RasterNeighbourhood3x3Error.none);
}



private
T invokeNeighbourhood3x3Kernel(alias kernel, T)(
    ref const(T)[9] neighbourhood
)
@safe
pure
nothrow
@nogc
{
    return kernel(neighbourhood);
}


/++
    Exact allocation-free fallback for differently shaped same-type source and
    destination sample-byte overlap.

    This is reached only if the normal checked-wide affine classifier reports
    arithmetic failure. It is not the normal large-raster path.
+/
private
bool asymmetricSampleBytesOverlapFallback(T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,
    size_t sourceWidth,
    size_t sourceHeight,

    scope T* destinationBase,
    ptrdiff_t destinationRowStrideElements,
    ptrdiff_t destinationSampleStrideElements,
    size_t destinationWidth,
    size_t destinationHeight
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(sourceWidth != 0);
    assert(sourceHeight != 0);
    assert(destinationWidth != 0);
    assert(destinationHeight != 0);

    auto sourceRow = sourceBase;

    foreach (sourceY; 0 .. sourceHeight)
    {
        auto sourceSample = sourceRow;

        foreach (sourceX; 0 .. sourceWidth)
        {
            const sourceAddress = cast(size_t) sourceSample;
            auto destinationRow = destinationBase;

            foreach (destinationY; 0 .. destinationHeight)
            {
                auto destinationSample = destinationRow;

                foreach (destinationX; 0 .. destinationWidth)
                {
                    const destinationAddress =
                        cast(size_t) destinationSample;

                    const distance =
                        sourceAddress <= destinationAddress
                        ? destinationAddress - sourceAddress
                        : sourceAddress - destinationAddress;

                    if (distance < T.sizeof)
                        return true;

                    if (destinationX + 1 < destinationWidth)
                        destinationSample += destinationSampleStrideElements;
                }

                if (destinationY + 1 < destinationHeight)
                    destinationRow += destinationRowStrideElements;
            }

            if (sourceX + 1 < sourceWidth)
                sourceSample += sourceSampleStrideElements;
        }

        if (sourceY + 1 < sourceHeight)
            sourceRow += sourceRowStrideElements;
    }

    return false;
}


/++
    Applies one compile-time same-type kernel to every 3 x 3 neighbourhood
    centered on sourceOutputRegion.

    sourceOutputRegion is relative to the supplied source view.

    For non-empty output, one resident source sample must exist on all four
    sides of sourceOutputRegion. Destination width and height must equal the
    output-region width and height.

    The operation defines no border policy and does not inspect logical/global
    dependency metadata or ContextDeficit.

    The kernel receives nine source values in row-major order. Index 4 is the
    center sample. The kernel must be usable as a safe, pure, nothrow, nogc
    same-type callable.

    Structural failures occur before the first destination write. Destination
    mapping must be injective, and the exact required source sample bytes must
    be physically disjoint from destination sample bytes.

    Matching empty output succeeds without requiring halo or invoking kernel.
+/
bool tryApplyRasterNeighbourhood3x3(alias kernel, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterNeighbourhood3x3Error error
)
@safe
nothrow
@nogc
{
    error = RasterNeighbourhood3x3Error.none;

    ptrdiff_t sourceRowStrideElements;
    ptrdiff_t sourceSampleStrideElements;

    if (!source.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        sourceRowStrideElements,
        sourceSampleStrideElements
    ))
    {
        error = RasterNeighbourhood3x3Error.invalidSourcePlane;
        return false;
    }

    ptrdiff_t destinationRowStrideElements;
    ptrdiff_t destinationSampleStrideElements;

    if (!destination.tryExecutionPlaneStrides(
        destinationPlaneIndex,
        destinationRowStrideElements,
        destinationSampleStrideElements
    ))
    {
        error = RasterNeighbourhood3x3Error.invalidDestinationPlane;
        return false;
    }

    if (
        destination.width != sourceOutputRegion.width
        || destination.height != sourceOutputRegion.height
    )
    {
        error = RasterNeighbourhood3x3Error.destinationShapeMismatch;
        return false;
    }

    if (!source.region.containsRelative(sourceOutputRegion))
    {
        error = RasterNeighbourhood3x3Error.unsatisfiedNeighbourhood;
        return false;
    }

    if (sourceOutputRegion.empty())
        return true;

    if (
        sourceOutputRegion.x == 0
        || sourceOutputRegion.y == 0
        || sourceOutputRegion.width
            >= source.width - sourceOutputRegion.x
        || sourceOutputRegion.height
            >= source.height - sourceOutputRegion.y
    )
    {
        error = RasterNeighbourhood3x3Error.unsatisfiedNeighbourhood;
        return false;
    }

    if (!affine2DMappingIsInjective(
        destination.width,
        destination.height,
        destinationRowStrideElements,
        destinationSampleStrideElements
    ))
    {
        error = RasterNeighbourhood3x3Error.nonInjectiveDestination;
        return false;
    }

    const requiredSourceRelative =
        Region2D(
            sourceOutputRegion.x - 1,
            sourceOutputRegion.y - 1,
            sourceOutputRegion.width + 2,
            sourceOutputRegion.height + 2
        );

    bool requiredSourceOk;

    scope auto requiredSource =
        source.tryRoi(
            requiredSourceRelative,
            requiredSourceOk
        );

    assert(requiredSourceOk);

    ptrdiff_t requiredSourceRowStrideElements;
    ptrdiff_t requiredSourceSampleStrideElements;

    assert(requiredSource.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        requiredSourceRowStrideElements,
        requiredSourceSampleStrideElements
    ));

    const sourceBase =
        requiredSource.executionRegionBase(sourcePlaneIndex);

    auto destinationBase =
        destination.executionRegionBase(destinationPlaneIndex);

    assert(sourceBase !is null);
    assert(destinationBase !is null);

    final switch (classifyValidatedSameTypeAffine2DRectanglesByteOverlap(
        requiredSource.width,
        requiredSource.height,
        cast(size_t) sourceBase,
        requiredSourceRowStrideElements,
        requiredSourceSampleStrideElements,

        destination.width,
        destination.height,
        cast(size_t) destinationBase,
        destinationRowStrideElements,
        destinationSampleStrideElements,

        T.sizeof
    ))
    {
        case AffineByteOverlapRelation.overlap:
            error = RasterNeighbourhood3x3Error.sourceDestinationOverlap;
            return false;

        case AffineByteOverlapRelation.disjoint:
            break;

        case AffineByteOverlapRelation.arithmeticFailure:
            if (asymmetricSampleBytesOverlapFallback(
                sourceBase,
                requiredSourceRowStrideElements,
                requiredSourceSampleStrideElements,
                requiredSource.width,
                requiredSource.height,

                destinationBase,
                destinationRowStrideElements,
                destinationSampleStrideElements,
                destination.width,
                destination.height
            ))
            {
                error = RasterNeighbourhood3x3Error.sourceDestinationOverlap;
                return false;
            }

            break;
    }

    if (
        requiredSourceSampleStrideElements == 1
        && destinationSampleStrideElements == 1
    )
    {
        executeApprovedNeighbourhood3x3!kernel(
            sourceBase,
            requiredSourceRowStrideElements,
            1,
            1,
            destination.width,
            destination.height,
            destinationBase,
            destinationRowStrideElements
        );

        return true;
    }


    /*
     * Generic validated affine fallback.
     *
     * Universal/sample-strided layouts retain the original semantic execution
     * path. No layout support is removed by the M3.1 optimization.
     */
    foreach (y; 0 .. destination.height)
    {
        foreach (x; 0 .. destination.width)
        {
            T[9] neighbourhood;
            size_t index;

            foreach (dy; 0 .. 3)
            {
                foreach (dx; 0 .. 3)
                {
                    const readOk =
                        source.trySample(
                            sourcePlaneIndex,
                            sourceOutputRegion.x + x + dx - 1,
                            sourceOutputRegion.y + y + dy - 1,
                            neighbourhood[index]
                        );

                    assert(readOk);
                    ++index;
                }
            }

            const transformed =
                invokeNeighbourhood3x3Kernel!kernel(
                    neighbourhood
                );

            const writeOk =
                destination.trySetSample(
                    destinationPlaneIndex,
                    x,
                    y,
                    transformed
                );

            assert(writeOk);
        }
    }

    return true;
}

/// Example reporting an invalid source plane for a 3 x 3 kernel.
@safe unittest
{
    import raster;
    alias center = (ref const(float)[9] values) @safe pure nothrow @nogc => values[4];
    RasterView!float source;
    WritableRasterView!float destination;
    RasterNeighbourhood3x3Error error;
    assert(!tryApplyRasterNeighbourhood3x3!center(
        source, 0, Region2D(0, 0, 1, 1), destination, 0, error));
    assert(error == RasterNeighbourhood3x3Error.invalidSourcePlane);
}



version (unittest)
{

import raster.descriptor : PlaneDescriptor;
import raster.resource : ResourceAccess, ResourceEntry;
import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;
import raster.view : makeRasterViewAssumeValidated;
import raster.writable_view : tryMakeWritableRasterView;


private
WritableRasterView!T makeWritableNeighbourhoodTestView(T)(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!T(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


@safe
pure
nothrow
@nogc
private
ubyte weightedNeighbourhood(ref const(ubyte)[9] n)
{
    const uint weighted =
          cast(uint) n[0]
        + cast(uint) n[1] * 2
        + cast(uint) n[2] * 3
        + cast(uint) n[3] * 5
        + cast(uint) n[4] * 7
        + cast(uint) n[5] * 11
        + cast(uint) n[6] * 13
        + cast(uint) n[7] * 17
        + cast(uint) n[8] * 19;

    return cast(ubyte)(weighted % 251);
}


@safe
pure
nothrow
@nogc
private
ubyte logicalNeighbourhoodValue(size_t x, size_t y)
{
    return cast(ubyte)(
        (
            cast(uint) x * 17
            + cast(uint) y * 29
            + cast(uint)(x ^ y) * 3
        )
        % 251
    );
}


@safe
pure
nothrow
@nogc
private
ubyte neighbourhoodOracleAt(size_t centerX, size_t centerY)
{
    ubyte[9] values;
    size_t index;

    foreach (dy; 0 .. 3)
    {
        foreach (dx; 0 .. 3)
        {
            values[index++] =
                logicalNeighbourhoodValue(
                    centerX + dx - 1,
                    centerY + dy - 1
                );
        }
    }

    return weightedNeighbourhood(values);
}


/*
 * Whole contiguous execution.
 */
unittest
{
    ubyte[25] sourceStorage;

    foreach (y; 0 .. 5)
        foreach (x; 0 .. 5)
            sourceStorage[y * 5 + x] =
                logicalNeighbourhoodValue(x, y);

    ubyte[9] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 5, 1)];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 3, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,3,3)
        );

    RasterNeighbourhood3x3Error error;

    assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source,
        0,
        Region2D(1,1,3,3),
        destination,
        0,
        error
    ));

    foreach (y; 0 .. 3)
        foreach (x; 0 .. 3)
            assert(
                destinationStorage[y * 3 + x]
                == neighbourhoodOracleAt(x + 1, y + 1)
            );
}


private
struct NeighbourhoodPair
{
    ushort a;
    ushort b;
}


@safe
pure
nothrow
@nogc
private
NeighbourhoodPair centerPair(
    ref const(NeighbourhoodPair)[9] neighbourhood
)
{
    return neighbourhood[4];
}


@safe
pure
nothrow
@nogc
private
float weightedFloatNeighbourhood(
    ref const(float)[9] n
)
{
    return
          n[0]
        + n[1] * 2.0f
        + n[2] * 3.0f
        + n[3] * 5.0f
        + n[4] * 7.0f
        + n[5] * 11.0f
        + n[6] * 13.0f
        + n[7] * 17.0f
        + n[8] * 19.0f;
}


/*
 * The Canonical executor remains generic over raster sample types.
 */
unittest
{
    NeighbourhoodPair[9] sourceStorage;

    foreach (index; 0 .. sourceStorage.length)
    {
        sourceStorage[index] =
            NeighbourhoodPair(
                cast(ushort) index,
                cast(ushort)(index + 100)
            );
    }

    NeighbourhoodPair[1] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 3, 1)];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 1, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!NeighbourhoodPair(
            sourceDescriptors[],
            Region2D(0,0,3,3)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!NeighbourhoodPair(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,1,1)
        );

    RasterNeighbourhood3x3Error error;

    assert(
        tryApplyRasterNeighbourhood3x3!centerPair(
            source,
            0,
            Region2D(1,1,1,1),
            destination,
            0,
            error
        )
    );

    assert(
        destinationStorage[0]
        == sourceStorage[4]
    );
}


/*
 * Float + negative Canonical source rows exercises the qualified LDC 2.111
 * row-boundary path and the ordinary Canonical executor on other compilers.
 *
 * Both must preserve identical public semantics.
 */
unittest
{
    enum size_t pitch = 7;

    float[pitch * 5] sourceStorage;

    foreach (y; 0 .. 5)
    {
        foreach (x; 0 .. 5)
        {
            sourceStorage[
                (4 - y) * pitch + x
            ] =
                cast(float)(
                    x + y * 10
                );
        }
    }

    float[9] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr + 4 * pitch,
            -cast(ptrdiff_t) pitch,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 3, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,3,3)
        );

    RasterNeighbourhood3x3Error error;

    assert(
        tryApplyRasterNeighbourhood3x3!weightedFloatNeighbourhood(
            source,
            0,
            Region2D(1,1,3,3),
            destination,
            0,
            error
        )
    );

    foreach (y; 0 .. 3)
    {
        foreach (x; 0 .. 3)
        {
            float[9] neighbourhood;
            size_t index;

            foreach (dy; 0 .. 3)
            {
                foreach (dx; 0 .. 3)
                {
                    neighbourhood[index++] =
                        cast(float)(
                            (x + dx)
                            + (y + dy) * 10
                        );
                }
            }

            assert(
                destinationStorage[
                    y * 3 + x
                ]
                == weightedFloatNeighbourhood(
                    neighbourhood
                )
            );
        }
    }
}


/*
 * Universal/sample-strided source and negative-row destination.
 */
unittest
{
    enum size_t sourcePitch = 12;
    enum size_t sourceSampleStride = 2;
    enum size_t destinationPitch = 5;

    ubyte[sourcePitch * 5] sourceStorage;

    foreach (y; 0 .. 5)
        foreach (x; 0 .. 5)
            sourceStorage[y * sourcePitch + x * sourceSampleStride] =
                logicalNeighbourhoodValue(x, y);

    ubyte[destinationPitch * 3] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            sourcePitch,
            sourceSampleStride
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr + 2 * destinationPitch,
            -cast(ptrdiff_t) destinationPitch,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,3,3)
        );

    RasterNeighbourhood3x3Error error;

    assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source,
        0,
        Region2D(1,1,3,3),
        destination,
        0,
        error
    ));

    foreach (y; 0 .. 3)
        foreach (x; 0 .. 3)
            assert(
                destinationStorage[(2-y) * destinationPitch + x]
                == neighbourhoodOracleAt(x + 1, y + 1)
            );
}


/*
 * Negative Canonical source rows remain supported.
 */
unittest
{
    enum size_t pitch = 7;

    ubyte[pitch * 5] sourceStorage;

    foreach (y; 0 .. 5)
        foreach (x; 0 .. 5)
            sourceStorage[(4-y) * pitch + x] =
                logicalNeighbourhoodValue(x, y);

    ubyte[9] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr + 4 * pitch,
            -cast(ptrdiff_t) pitch,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 3, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,3,3)
        );

    RasterNeighbourhood3x3Error error;

    assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source,
        0,
        Region2D(1,1,3,3),
        destination,
        0,
        error
    ));

    foreach (y; 0 .. 3)
        foreach (x; 0 .. 3)
            assert(
                destinationStorage[y * 3 + x]
                == neighbourhoodOracleAt(x + 1, y + 1)
            );
}


/*
 * Independently materialized task-local halos reassemble exactly to the whole
 * result. This qualifies the public operation itself rather than only the M1.7
 * test-local oracle.
 */
unittest
{
    enum size_t sourceWidth = 5;
    enum size_t sourceHeight = 5;
    enum size_t outputWidth = 3;
    enum size_t outputHeight = 3;

    ubyte[sourceWidth * sourceHeight] wholeSourceStorage;

    foreach (y; 0 .. sourceHeight)
        foreach (x; 0 .. sourceWidth)
            wholeSourceStorage[y * sourceWidth + x] =
                logicalNeighbourhoodValue(x, y);

    ubyte[outputWidth * outputHeight] wholeDestinationStorage;

    const PlaneDescriptor[1] wholeSourceDescriptors =
        [PlaneDescriptor(wholeSourceStorage.ptr, sourceWidth, 1)];

    const PlaneDescriptor[1] wholeDestinationDescriptors =
        [PlaneDescriptor(wholeDestinationStorage.ptr, outputWidth, 1)];

    const ResourceEntry[1] wholeDestinationResources =
    [
        ResourceEntry(
            wholeDestinationStorage.ptr,
            wholeDestinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto wholeSource =
        makeRasterViewAssumeValidated!ubyte(
            wholeSourceDescriptors[],
            Region2D(0,0,sourceWidth,sourceHeight)
        );

    scope auto wholeDestination =
        makeWritableNeighbourhoodTestView!ubyte(
            wholeDestinationResources[],
            wholeDestinationDescriptors[],
            Region2D(0,0,outputWidth,outputHeight)
        );

    RasterNeighbourhood3x3Error error;

    assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        wholeSource,
        0,
        Region2D(1,1,outputWidth,outputHeight),
        wholeDestination,
        0,
        error
    ));

    ubyte[outputWidth * outputHeight] streamed;

    foreach (taskIndex; 0 .. 2)
    {
        const size_t outputY = taskIndex == 0 ? 0 : 1;
        const size_t taskHeight = taskIndex == 0 ? 1 : 2;
        const size_t residentHeight = taskHeight + 2;

        ubyte[sourceWidth * 4] taskSourceStorage;
        ubyte[outputWidth * 2] taskDestinationStorage;

        foreach (residentY; 0 .. residentHeight)
            foreach (x; 0 .. sourceWidth)
                taskSourceStorage[residentY * sourceWidth + x] =
                    logicalNeighbourhoodValue(x, outputY + residentY);

        const PlaneDescriptor[1] taskSourceDescriptors =
            [PlaneDescriptor(taskSourceStorage.ptr, sourceWidth, 1)];

        const PlaneDescriptor[1] taskDestinationDescriptors =
            [PlaneDescriptor(taskDestinationStorage.ptr, outputWidth, 1)];

        const ResourceEntry[1] taskDestinationResources =
        [
            ResourceEntry(
                taskDestinationStorage.ptr,
                taskDestinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto taskSource =
            makeRasterViewAssumeValidated!ubyte(
                taskSourceDescriptors[],
                Region2D(0,0,sourceWidth,residentHeight)
            );

        scope auto taskDestination =
            makeWritableNeighbourhoodTestView!ubyte(
                taskDestinationResources[],
                taskDestinationDescriptors[],
                Region2D(0,0,outputWidth,taskHeight)
            );

        assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
            taskSource,
            0,
            Region2D(1,1,outputWidth,taskHeight),
            taskDestination,
            0,
            error
        ));

        foreach (y; 0 .. taskHeight)
            foreach (x; 0 .. outputWidth)
                streamed[(outputY + y) * outputWidth + x] =
                    taskDestinationStorage[y * outputWidth + x];
    }

    assert(streamed == wholeDestinationStorage);
}


/*
 * Structural failures occur before writing.
 */
unittest
{
    ubyte[25] sourceStorage;
    ubyte[4] destinationStorage = [7,7,7,7];

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 5, 1)];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 2, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,2,2)
        );

    RasterNeighbourhood3x3Error error;

    assert(!tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source, 1, Region2D(1,1,2,2), destination, 0, error));
    assert(error == RasterNeighbourhood3x3Error.invalidSourcePlane);

    assert(!tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source, 0, Region2D(1,1,2,2), destination, 1, error));
    assert(error == RasterNeighbourhood3x3Error.invalidDestinationPlane);

    assert(!tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source, 0, Region2D(1,1,1,2), destination, 0, error));
    assert(error == RasterNeighbourhood3x3Error.destinationShapeMismatch);

    assert(!tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source, 0, Region2D(0,0,2,2), destination, 0, error));
    assert(error == RasterNeighbourhood3x3Error.unsatisfiedNeighbourhood);

    assert(destinationStorage == [7,7,7,7]);
}


/*
 * One 3 x 3 resident neighbourhood produces exactly one destination sample.
 */
unittest
{
    ubyte[9] sourceStorage;

    foreach (y; 0 .. 3)
        foreach (x; 0 .. 3)
            sourceStorage[y * 3 + x] =
                logicalNeighbourhoodValue(x, y);

    ubyte[1] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 3, 1)];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 1, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,3,3)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,1,1)
        );

    RasterNeighbourhood3x3Error error;

    assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source,
        0,
        Region2D(1,1,1,1),
        destination,
        0,
        error
    ));

    assert(
        destinationStorage[0]
        == neighbourhoodOracleAt(1,1)
    );
}


/*
 * Non-injective destination is rejected before the first write.
 */
unittest
{
    ubyte[25] sourceStorage;
    ubyte[1] destinationStorage = [55];

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 5, 1)];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 0, 0)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,3,3)
        );

    RasterNeighbourhood3x3Error error;

    assert(!tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source,
        0,
        Region2D(1,1,3,3),
        destination,
        0,
        error
    ));

    assert(
        error
        == RasterNeighbourhood3x3Error.nonInjectiveDestination
    );

    assert(destinationStorage[0] == 55);
}


/*
 * Physical overlap is rejected before writing.
 */
unittest
{
    ubyte[25] storage;

    foreach (i; 0 .. storage.length)
        storage[i] = cast(ubyte)i;

    const original = storage;

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(storage.ptr, 5, 1)];

    const PlaneDescriptor[1] overlapDestinationDescriptors =
        [PlaneDescriptor(storage.ptr + 6, 3, 1)];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,5,5)
        );

    scope auto overlapDestination =
        makeWritableNeighbourhoodTestView!ubyte(
            resources[],
            overlapDestinationDescriptors[],
            Region2D(0,0,3,3)
        );

    RasterNeighbourhood3x3Error error;

    assert(!tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source,
        0,
        Region2D(1,1,3,3),
        overlapDestination,
        0,
        error
    ));

    assert(error == RasterNeighbourhood3x3Error.sourceDestinationOverlap);
    assert(storage == original);
}


/*
 * Matching empty output succeeds without invoking the kernel.
 */
@safe
pure
nothrow
@nogc
private
ubyte neighbourhoodMustNotRun(ref const(ubyte)[9])
{
    assert(0);
}


unittest
{
    ubyte[1] sourceStorage;
    ubyte[1] destinationStorage = [91];

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 1, 1)];

    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 1, 1)];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,1,1)
        );

    scope auto destination =
        makeWritableNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,0,0)
        );

    RasterNeighbourhood3x3Error error;

    assert(tryApplyRasterNeighbourhood3x3!neighbourhoodMustNotRun(
        source,
        0,
        Region2D(0,0,0,0),
        destination,
        0,
        error
    ));

    assert(error == RasterNeighbourhood3x3Error.none);
    assert(destinationStorage[0] == 91);
}


/*
 * Defensive fallback is independently exact.
 */
unittest
{
    ubyte[5] sourceStorage;
    ubyte[3] destinationStorage;

    assert(!asymmetricSampleBytesOverlapFallback(
        sourceStorage.ptr,
        5,
        1,
        5,
        1,
        destinationStorage.ptr,
        3,
        1,
        3,
        1
    ));

    assert(asymmetricSampleBytesOverlapFallback(
        sourceStorage.ptr,
        5,
        1,
        5,
        1,
        sourceStorage.ptr + 1,
        3,
        1,
        3,
        1
    ));
}

// Shared backing with overlapping envelopes and disjoint reachable bytes.
unittest
{
    ubyte[18] storage;
    foreach (y; 0 .. 3)
    foreach (x; 0 .. 3) storage[6*y+2*x] = logicalNeighbourhoodValue(x,y);
    const original = storage;
    const PlaneDescriptor[1] src = [PlaneDescriptor(storage.ptr, 6, 2)];
    const PlaneDescriptor[1] dst = [PlaneDescriptor(storage.ptr+1, 2, 2)];
    const ResourceEntry[1] resources = [ResourceEntry(storage.ptr, storage.sizeof,
        null, null, ResourceAccess.readWrite)];
    scope auto source = makeRasterViewAssumeValidated!ubyte(src[], Region2D(0,0,3,3));
    scope auto target = makeWritableNeighbourhoodTestView!ubyte(resources[], dst[], Region2D(0,0,1,1));
    RasterNeighbourhood3x3Error error;
    assert(tryApplyRasterNeighbourhood3x3!weightedNeighbourhood(
        source, 0, Region2D(1,1,1,1), target, 0, error));
    assert(storage[1] == neighbourhoodOracleAt(1,1));
    foreach (i; 0 .. storage.length) if (i != 1) assert(storage[i] == original[i]);
}

} // version (unittest)
