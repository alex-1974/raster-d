/++
    Public fixed 3 x 3 raster neighbourhood operation.

    M2.3 exposes one semantic radius-one neighbourhood primitive over an
    already-materialized resident source. Logical dependency derivation,
    ContextDeficit interpretation, border policy, execution specialization and
    scheduling remain outside this public contract.
+/
module raster.neighbourhood;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DRectanglesByteOverlap;

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

    final switch (classifySameTypeAffine2DRectanglesByteOverlap(
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
                invokeNeighbourhood3x3Kernel!kernel(neighbourhood);

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
 * Non-injective destination and physical overlap are rejected before writing.
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

} // version (unittest)
