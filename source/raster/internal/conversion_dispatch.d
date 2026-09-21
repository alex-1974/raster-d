/++
    Internal dispatch for exact ubyte-to-float raster conversion.

    E5.3b combines:

    - logical source/target validation;
    - execution capability derived from RasterView;
    - a pairwise physical source/target non-overlap check;
    - the E5.3a scalar conversion reference kernel.

    The physical-range logic deliberately remains local to this operation in
    E5.3b. E5.3c will compare it with checked copy before deciding whether a
    shared lower-level abstraction is justified.

    No public raster-operation API is defined here.
+/
module raster.internal.conversion_dispatch;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifyUbyteToFloatAffine2DByteOverlap;

import raster.internal.execution_layout :
    PlaneExecutionTraits;

import raster.internal.mir_adapter :
    asMirContiguousFlat;

import raster.internal.mir_target_adapter :
    asMirTargetContiguousFlat;

import raster.internal.physical_range :
    PhysicalByteRangeRelation,
    classifyByteAddressRanges;

import raster.internal.scalar_conversion :
    scalarConvertUbyteToFloatContiguous1D;

import raster.internal.target :
    RasterTargetPlane,
    tryBorrowContiguousTarget;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Failure category for checked flat ubyte-to-float conversion.
+/
package(raster)
enum UbyteToFloatConversionError : ubyte
{
    none,

    invalidPlaneIndex,

    shapeMismatch,

    unsupportedExecution,

    overlapDetected,

    addressRangeUnrepresentable,

    invalidTargetPlaneIndex,

    nonInjectiveTarget
}


/++
    Result of one package-internal ubyte-to-float conversion dispatch.

    `.init` deliberately represents failure rather than success.
+/
package(raster)
struct UbyteToFloatConversionResult
{
    UbyteToFloatConversionError error =
        UbyteToFloatConversionError.addressRangeUnrepresentable;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == UbyteToFloatConversionError.none;
    }
}


private
UbyteToFloatConversionResult conversionSuccess()
@safe
pure
nothrow
@nogc
{
    UbyteToFloatConversionResult result;

    result.error =
        UbyteToFloatConversionError.none;

    return result;
}


private
UbyteToFloatConversionResult conversionFailure(
    UbyteToFloatConversionError error
)
@safe
pure
nothrow
@nogc
{
    UbyteToFloatConversionResult result;

    result.error =
        error;

    return result;
}


/++
    Classifies the physical ranges used by one non-empty ubyte-to-float
    conversion.

    Unlike same-type copy, the source and target byte lengths differ:

        sourceByteLength = elementCount * ubyte.sizeof
        targetByteLength = elementCount * float.sizeof

    The function converts pointers to the project's flat integer-address
    representation and validates all byte-length and end-address arithmetic
    before comparing the half-open ranges.

    No source or target memory is dereferenced or modified here.
+/
private
PhysicalByteRangeRelation classifyConversionPhysicalRanges(
    scope const(ubyte)* sourceBase,
    scope float* targetBase,
    size_t elementCount
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(targetBase !is null);
    assert(elementCount != 0);

    if (
        elementCount
        > size_t.max / ubyte.sizeof
    )
    {
        return
            PhysicalByteRangeRelation.unrepresentable;
    }

    if (
        elementCount
        > size_t.max / float.sizeof
    )
    {
        return
            PhysicalByteRangeRelation.unrepresentable;
    }

    const sourceByteLength =
        elementCount * ubyte.sizeof;

    const targetByteLength =
        elementCount * float.sizeof;

    const sourceStart =
        cast(size_t) sourceBase;

    const targetStart =
        cast(size_t) targetBase;

    return classifyByteAddressRanges(
        sourceStart,
        sourceByteLength,
        targetStart,
        targetByteLength
    );
}


/++
    Converts validated affine execution pointers to machine addresses and
    delegates exact ubyte-to-float physical relation classification.

    Pointer-to-integer conversion remains operation-local.

    No source or target sample is dereferenced here.
+/
private
AffineByteOverlapRelation classifyUbyteToFloatAffinePhysicalRelation(
    scope const(ubyte)* sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    scope float* targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,

    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(targetBase !is null);

    return classifyUbyteToFloatAffine2DByteOverlap(
        width,
        height,

        cast(size_t) sourceBase,
        sourceRowStrideElements,
        sourceSampleStrideElements,

        cast(size_t) targetBase,
        targetRowStrideElements,
        targetSampleStrideElements
    );
}


/++
    Executes an already-approved affine ubyte-to-float conversion.

    All relation failures have been resolved before entry.

    RasterView and WritableRasterView remain the semantic sample-access
    boundaries.
+/
private
void convertApprovedUbyteToFloatAffine2D(
    scope RasterView!ubyte source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!float target,
    size_t targetPlaneIndex
)
@safe
nothrow
@nogc
{
    foreach (y; 0 .. source.height)
    {
        foreach (x; 0 .. source.width)
        {
            ubyte sourceValue;

            const readOk =
                source.trySample(
                    sourcePlaneIndex,
                    x,
                    y,
                    sourceValue
                );

            assert(readOk);


            const writeOk =
                target.trySetSample(
                    targetPlaneIndex,
                    x,
                    y,
                    cast(float) sourceValue
                );

            assert(writeOk);
        }
    }
}


/++
    Converts one affine ubyte source plane into one affine float destination
    after establishing the E5.4f bulk-write relation contract.

    Source self-aliasing is permitted.

    The finite destination mapping must be injective.

    Actual physical source/target sample-byte overlap is rejected before the
    first target write.

    The operation checks:

    - source plane index;
    - target plane index;
    - logical shape;
    - empty shape;
    - destination injectivity;
    - exact ubyte-to-float physical sample-byte overlap;
    - scalar semantic conversion.

    No persistent alias or injectivity proof is created.
+/
package(raster)
UbyteToFloatConversionResult tryConvertUbyteToFloatAffine2D(
    scope RasterView!ubyte source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!float target,
    size_t targetPlaneIndex
)
@safe
nothrow
@nogc
{
    ptrdiff_t sourceRowStrideElements;
    ptrdiff_t sourceSampleStrideElements;

    if (
        !source.tryExecutionPlaneStrides(
            sourcePlaneIndex,
            sourceRowStrideElements,
            sourceSampleStrideElements
        )
    )
    {
        return conversionFailure(
            UbyteToFloatConversionError.invalidPlaneIndex
        );
    }


    ptrdiff_t targetRowStrideElements;
    ptrdiff_t targetSampleStrideElements;

    if (
        !target.tryExecutionPlaneStrides(
            targetPlaneIndex,
            targetRowStrideElements,
            targetSampleStrideElements
        )
    )
    {
        return conversionFailure(
            UbyteToFloatConversionError.invalidTargetPlaneIndex
        );
    }


    if (
        source.width != target.width
        || source.height != target.height
    )
    {
        return conversionFailure(
            UbyteToFloatConversionError.shapeMismatch
        );
    }


    if (source.empty)
        return conversionSuccess();


    if (
        !affine2DMappingIsInjective(
            target.width,
            target.height,
            targetRowStrideElements,
            targetSampleStrideElements
        )
    )
    {
        return conversionFailure(
            UbyteToFloatConversionError.nonInjectiveTarget
        );
    }


    const sourceBase =
        source.executionRegionBase(
            sourcePlaneIndex
        );

    auto targetBase =
        target.executionRegionBase(
            targetPlaneIndex
        );

    assert(sourceBase !is null);
    assert(targetBase !is null);


    final switch (
        classifyUbyteToFloatAffinePhysicalRelation(
            sourceBase,
            sourceRowStrideElements,
            sourceSampleStrideElements,

            targetBase,
            targetRowStrideElements,
            targetSampleStrideElements,

            source.width,
            source.height
        )
    )
    {
        case AffineByteOverlapRelation.overlap:
            return conversionFailure(
                UbyteToFloatConversionError.overlapDetected
            );

        case AffineByteOverlapRelation.arithmeticFailure:
            return conversionFailure(
                UbyteToFloatConversionError.addressRangeUnrepresentable
            );

        case AffineByteOverlapRelation.disjoint:
        {
            convertApprovedUbyteToFloatAffine2D(
                source,
                sourcePlaneIndex,
                target,
                targetPlaneIndex
            );

            return conversionSuccess();
        }
    }
}


/++
    Converts one ubyte source plane into a contiguous float target.

    Preconditions are established internally in this order:

    - plane index must be valid;
    - source and target logical width/height must match;
    - matching empty shapes succeed without forming physical ranges;
    - source must provide flat Contiguous 1D execution;
    - source and target physical byte intervals must be representable;
    - those intervals must not overlap.

    Failure occurs before the first target write.

    On successful non-empty dispatch the E5.3a scalar reference kernel performs
    the exact per-sample conversion:

        target[i] = cast(float) source[i]
+/
package(raster)
UbyteToFloatConversionResult tryConvertUbyteToFloatContiguous1D(
    scope RasterView!ubyte source,
    size_t planeIndex,
    scope RasterTargetPlane!float target
)
@safe
nothrow
@nogc
{
    PlaneExecutionTraits traits;

    if (
        !source.tryPlaneExecutionTraits(
            planeIndex,
            traits
        )
    )
    {
        return conversionFailure(
            UbyteToFloatConversionError.invalidPlaneIndex
        );
    }

    if (
        source.width != target.width
        || source.height != target.height
    )
    {
        return conversionFailure(
            UbyteToFloatConversionError.shapeMismatch
        );
    }

    /*
     * Matching empty shapes contain no samples and therefore no physical
     * source/target sample intervals requiring an alias proof.
     */
    if (source.empty)
        return conversionSuccess();

    if (!traits.linearContiguous1D)
    {
        return conversionFailure(
            UbyteToFloatConversionError.unsupportedExecution
        );
    }

    assert(
        traits.flatElementCount
        == target.elementCount
    );

    const sourceBase =
        source.executionRegionBase(
            planeIndex
        );

    auto targetBase =
        target.executionBase();

    assert(sourceBase !is null);
    assert(targetBase !is null);

    final switch (
        classifyConversionPhysicalRanges(
            sourceBase,
            targetBase,
            traits.flatElementCount
        )
    )
    {
        case PhysicalByteRangeRelation.overlapping:
            return conversionFailure(
                UbyteToFloatConversionError.overlapDetected
            );

        case PhysicalByteRangeRelation.unrepresentable:
            return conversionFailure(
                UbyteToFloatConversionError.addressRangeUnrepresentable
            );

        case PhysicalByteRangeRelation.nonOverlapping:
        {
            const converted =
                scalarConvertUbyteToFloatContiguous1D(
                    asMirContiguousFlat(
                        source,
                        planeIndex
                    ),
                    asMirTargetContiguousFlat(
                        target
                    )
                );

            /*
             * Shape equality and the source flat element count were already
             * established above.
             */
            assert(converted);

            return conversionSuccess();
        }
    }
}


/++
    Semantic failure categories for the stable exact ubyte-to-float
    raster-plane conversion.

    Execution availability and arithmetic-carrier states are deliberately not
    represented here.
+/
package(raster)
enum ExactUbyteToFloatRasterError : ubyte
{
    none,

    invalidSourcePlane,

    invalidDestinationPlane,

    shapeMismatch,

    nonInjectiveDestination,

    sourceDestinationOverlap
}


/++
    Exact allocation-free fallback for ubyte-source / float-destination
    sample-byte overlap.

    This path is reached only if the checked-wide affine classifier reports its
    defensive arithmetic-failure state.

    All represented pointers come from already validated RasterView and
    WritableRasterView execution metadata.

    A one-byte ubyte source sample overlaps a four-byte float destination sample
    exactly when the source byte address lies inside the destination interval.

    Classification completes before any destination write.
+/
private
bool ubyteToFloatSampleBytesOverlapFallback(
    scope const(ubyte)* sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    scope float* destinationBase,
    ptrdiff_t destinationRowStrideElements,
    ptrdiff_t destinationSampleStrideElements,

    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(width != 0);
    assert(height != 0);

    auto sourceRow =
        sourceBase;

    foreach (sourceY; 0 .. height)
    {
        auto sourceSample =
            sourceRow;

        foreach (sourceX; 0 .. width)
        {
            const sourceAddress =
                cast(size_t) sourceSample;

            auto destinationRow =
                destinationBase;

            foreach (destinationY; 0 .. height)
            {
                auto destinationSample =
                    destinationRow;

                foreach (destinationX; 0 .. width)
                {
                    const destinationAddress =
                        cast(size_t) destinationSample;

                    if (
                        sourceAddress >= destinationAddress
                        && sourceAddress - destinationAddress
                            < float.sizeof
                    )
                    {
                        return true;
                    }

                    if (destinationX + 1 < width)
                    {
                        destinationSample +=
                            destinationSampleStrideElements;
                    }
                }

                if (destinationY + 1 < height)
                {
                    destinationRow +=
                        destinationRowStrideElements;
                }
            }

            if (sourceX + 1 < width)
            {
                sourceSample +=
                    sourceSampleStrideElements;
            }
        }

        if (sourceY + 1 < height)
        {
            sourceRow +=
                sourceRowStrideElements;
        }
    }

    return false;
}


/++
    Executes the stable exact ubyte-to-float raster-plane semantic.

    All semantic relation checks complete before the first destination write.

    Fast-path selection is internal:

    - flat contiguous source + destination use the established Mir-backed
      scalar contiguous reference kernel after exact physical range
      classification;
    - every other validated layout uses exact affine relation classification
      plus semantic scalar conversion;
    - a defensive checked-wide arithmetic failure falls back to exact
      allocation-free pairwise byte classification.

    This function exposes neither `unsupportedExecution` nor
    `addressRangeUnrepresentable`.
+/
package(raster)
ExactUbyteToFloatRasterError convertUbyteToFloatRasterPlane(
    scope RasterView!ubyte source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!float destination,
    size_t destinationPlaneIndex
)
@safe
nothrow
@nogc
{
    ptrdiff_t sourceRowStrideElements;
    ptrdiff_t sourceSampleStrideElements;

    if (
        !source.tryExecutionPlaneStrides(
            sourcePlaneIndex,
            sourceRowStrideElements,
            sourceSampleStrideElements
        )
    )
    {
        return
            ExactUbyteToFloatRasterError.invalidSourcePlane;
    }


    ptrdiff_t destinationRowStrideElements;
    ptrdiff_t destinationSampleStrideElements;

    if (
        !destination.tryExecutionPlaneStrides(
            destinationPlaneIndex,
            destinationRowStrideElements,
            destinationSampleStrideElements
        )
    )
    {
        return
            ExactUbyteToFloatRasterError.invalidDestinationPlane;
    }


    if (
        source.width != destination.width
        || source.height != destination.height
    )
    {
        return
            ExactUbyteToFloatRasterError.shapeMismatch;
    }


    if (source.empty)
    {
        return
            ExactUbyteToFloatRasterError.none;
    }


    if (
        !affine2DMappingIsInjective(
            destination.width,
            destination.height,
            destinationRowStrideElements,
            destinationSampleStrideElements
        )
    )
    {
        return
            ExactUbyteToFloatRasterError.nonInjectiveDestination;
    }


    bool destinationContiguous;

    scope auto contiguousDestination =
        tryBorrowContiguousTarget(
            destination,
            destinationPlaneIndex,
            destinationContiguous
        );


    if (destinationContiguous)
    {
        PlaneExecutionTraits sourceTraits;

        const sourceTraitsOk =
            source.tryPlaneExecutionTraits(
                sourcePlaneIndex,
                sourceTraits
            );

        assert(sourceTraitsOk);

        if (sourceTraits.linearContiguous1D)
        {
            assert(
                sourceTraits.flatElementCount
                == contiguousDestination.elementCount
            );

            const sourceBase =
                source.executionRegionBase(
                    sourcePlaneIndex
                );

            auto destinationBase =
                contiguousDestination.executionBase();

            assert(sourceBase !is null);
            assert(destinationBase !is null);

            final switch (
                classifyConversionPhysicalRanges(
                    sourceBase,
                    destinationBase,
                    sourceTraits.flatElementCount
                )
            )
            {
                case PhysicalByteRangeRelation.overlapping:
                    return
                        ExactUbyteToFloatRasterError
                            .sourceDestinationOverlap;

                case PhysicalByteRangeRelation.nonOverlapping:
                {
                    const converted =
                        scalarConvertUbyteToFloatContiguous1D(
                            asMirContiguousFlat(
                                source,
                                sourcePlaneIndex
                            ),
                            asMirTargetContiguousFlat(
                                contiguousDestination
                            )
                        );

                    assert(converted);

                    return
                        ExactUbyteToFloatRasterError.none;
                }

                case PhysicalByteRangeRelation.unrepresentable:
                    /*
                     * Continue to exact affine classification instead of
                     * exposing arithmetic representation as a semantic error.
                     */
                    break;
            }
        }
    }


    const sourceBase =
        source.executionRegionBase(
            sourcePlaneIndex
        );

    auto destinationBase =
        destination.executionRegionBase(
            destinationPlaneIndex
        );

    assert(sourceBase !is null);
    assert(destinationBase !is null);


    final switch (
        classifyUbyteToFloatAffinePhysicalRelation(
            sourceBase,
            sourceRowStrideElements,
            sourceSampleStrideElements,

            destinationBase,
            destinationRowStrideElements,
            destinationSampleStrideElements,

            source.width,
            source.height
        )
    )
    {
        case AffineByteOverlapRelation.overlap:
            return
                ExactUbyteToFloatRasterError
                    .sourceDestinationOverlap;

        case AffineByteOverlapRelation.disjoint:
        {
            convertApprovedUbyteToFloatAffine2D(
                source,
                sourcePlaneIndex,
                destination,
                destinationPlaneIndex
            );

            return
                ExactUbyteToFloatRasterError.none;
        }

        case AffineByteOverlapRelation.arithmeticFailure:
        {
            if (
                ubyteToFloatSampleBytesOverlapFallback(
                    sourceBase,
                    sourceRowStrideElements,
                    sourceSampleStrideElements,

                    destinationBase,
                    destinationRowStrideElements,
                    destinationSampleStrideElements,

                    source.width,
                    source.height
                )
            )
            {
                return
                    ExactUbyteToFloatRasterError
                        .sourceDestinationOverlap;
            }

            convertApprovedUbyteToFloatAffine2D(
                source,
                sourcePlaneIndex,
                destination,
                destinationPlaneIndex
            );

            return
                ExactUbyteToFloatRasterError.none;
        }
    }
}


version (unittest)
{

import core.stdc.stdlib :
    malloc;

import raster.backing :
    RasterLease;

import raster.byte_layout :
    PlaneByteLayout;

import raster.descriptor :
    PlaneDescriptor;

import raster.import_owned :
    tryImportOwnedRaster;

import raster.internal.target :
    tryBorrowContiguousTarget;

import raster.owned_resource :
    OwnedByteResource,
    tryAdoptMallocResource;

import raster.region :
    Region2D;

import raster.resource :
    ResourceAccess,
    ResourceEntry;

import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import raster.view :
    makeRasterViewAssumeValidated;

import raster.writable_view :
    tryMakeWritableRasterView;


/*
 * Exact affine classification accepts overlapping physical envelopes when no
 * source byte actually intersects a target float sample.
 *
 * Source bytes are at offsets 4 and 12.
 *
 * Target float samples occupy byte intervals:
 *
 *     [0,4)
 *     [8,12)
 */
unittest
{
    union Storage
    {
        ubyte[16] bytes;
        float[4] floats;
    }

    Storage storage;

    storage.bytes[4] = 10;
    storage.bytes[12] = 20;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.bytes.ptr,
            storage.bytes.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.bytes.ptr + 4,
            0,
            8
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            storage.floats.ptr,
            0,
            2
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!float(
            resources[],
            targetDescriptors[],
            Region2D(0, 0, 2, 1),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryConvertUbyteToFloatAffine2D(
            source,
            0,
            target,
            0
        );

    assert(result.ok);

    assert(storage.floats[0] == 10.0f);
    assert(storage.floats[2] == 20.0f);

    assert(storage.bytes[4] == 10);
    assert(storage.bytes[12] == 20);
}


/*
 * A source byte inside the target float interval is rejected before writing.
 */
unittest
{
    union Storage
    {
        ubyte[16] bytes;
        float[4] floats;
    }

    Storage storage;

    storage.bytes[3] = 77;

    const ubyte[16] expected =
        storage.bytes;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.bytes.ptr,
            storage.bytes.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.bytes.ptr + 3,
            0,
            0
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            storage.floats.ptr,
            0,
            0
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!float(
            resources[],
            targetDescriptors[],
            Region2D(0, 0, 1, 1),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryConvertUbyteToFloatAffine2D(
            source,
            0,
            target,
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.overlapDetected
    );

    assert(storage.bytes == expected);
}


/*
 * A writable but non-injective float destination is rejected before the first
 * conversion write.
 */
unittest
{
    ubyte[6] sourceStorage =
        [1, 2, 3, 4, 5, 6];

    float[5] targetStorage =
        [9, 9, 9, 9, 9];

    const float[5] expected =
        targetStorage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            targetStorage.ptr,
            targetStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            3,
            1
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            targetStorage.ptr,
            2,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!float(
            resources[],
            targetDescriptors[],
            Region2D(0, 0, 3, 2),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryConvertUbyteToFloatAffine2D(
            source,
            0,
            target,
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.nonInjectiveTarget
    );

    assert(targetStorage == expected);
}


/*
 * Negative destination sample stride remains valid when the mapping is
 * injective and the two operands are physically disjoint.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    float[4] targetStorage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            targetStorage.ptr,
            targetStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            4,
            1
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            &targetStorage[3],
            0,
            -1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!float(
            resources[],
            targetDescriptors[],
            Region2D(0, 0, 4, 1),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryConvertUbyteToFloatAffine2D(
            source,
            0,
            target,
            0
        );

    assert(result.ok);

    assert(
        targetStorage
        == [4.0f, 3.0f, 2.0f, 1.0f]
    );
}


/*
 * Source self-aliasing remains permitted.
 */
unittest
{
    ubyte[1] sourceStorage =
        [77];

    float[6] targetStorage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            targetStorage.ptr,
            targetStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            0,
            0
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            targetStorage.ptr,
            3,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!float(
            resources[],
            targetDescriptors[],
            Region2D(0, 0, 3, 2),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryConvertUbyteToFloatAffine2D(
            source,
            0,
            target,
            0
        );

    assert(result.ok);

    foreach (value; targetStorage)
        assert(value == 77.0f);
}


/*
 * Distinct flat source and target storage converts successfully.
 */
unittest
{
    ubyte[6] sourceStorage =
        [0, 1, 127, 128, 254, 255];

    float[6] targetStorage =
        [-1.0f, -1.0f, -1.0f, -1.0f, -1.0f, -1.0f];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            3,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                3,
                2
            )
        );

    bool success;

    auto target =
        tryBorrowContiguousTarget(
            targetStorage[],
            3,
            2,
            success
        );

    assert(success);

    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            0,
            target
        );

    assert(result.ok);

    const float[6] expected =
        [0.0f, 1.0f, 127.0f, 128.0f, 254.0f, 255.0f];

    assert(targetStorage == expected);
}


/*
 * Logical shape mismatch fails before the first target write even when both
 * operands contain the same number of elements.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    float[4] targetStorage =
        [91.0f, 92.0f, 93.0f, 94.0f];

    const float[4] expected =
        targetStorage;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            4,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                4,
                1
            )
        );

    bool success;

    auto target =
        tryBorrowContiguousTarget(
            targetStorage[],
            2,
            2,
            success
        );

    assert(success);

    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.shapeMismatch
    );

    assert(targetStorage == expected);
}


/*
 * A padded Canonical source is not flat Contiguous 1D and is rejected before
 * the target is modified.
 */
unittest
{
    ubyte[8] sourceStorage =
        [1, 2, 3, 99, 4, 5, 6, 99];

    float[6] targetStorage =
        [51.0f, 52.0f, 53.0f, 54.0f, 55.0f, 56.0f];

    const float[6] expected =
        targetStorage;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            4,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                3,
                2
            )
        );

    bool success;

    auto target =
        tryBorrowContiguousTarget(
            targetStorage[],
            3,
            2,
            success
        );

    assert(success);

    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.unsupportedExecution
    );

    assert(targetStorage == expected);
}


/*
 * Matching empty shapes succeed before execution-pointer formation or
 * non-empty capability requirements.
 */
unittest
{
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            null,
            ptrdiff_t.min,
            ptrdiff_t.min
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                size_t.max,
                size_t.max,
                0,
                7
            )
        );

    float[] targetStorage;

    bool success;

    auto target =
        tryBorrowContiguousTarget(
            targetStorage,
            0,
            7,
            success
        );

    assert(success);

    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            0,
            target
        );

    assert(result.ok);
}


/*
 * An invalid source plane index is reported distinctly.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    float[4] targetStorage;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            4,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                4,
                1
            )
        );

    bool success;

    auto target =
        tryBorrowContiguousTarget(
            targetStorage[],
            4,
            1,
            success
        );

    assert(success);

    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            1,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.invalidPlaneIndex
    );
}


/*
 * Source and target may occupy the same underlying storage. Such overlap is
 * detected before the conversion kernel writes the target.
 */
unittest
{
    union SharedStorage
    {
        ubyte[16] bytes;
        float[4] floats;
    }

    SharedStorage storage;

    storage.floats =
        [91.0f, 92.0f, 93.0f, 94.0f];

    const float[4] expected =
        storage.floats;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.bytes.ptr,
            4,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                4,
                1
            )
        );

    bool success;

    auto target =
        tryBorrowContiguousTarget(
            storage.floats[],
            4,
            1,
            success
        );

    assert(success);

    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.overlapDetected
    );

    assert(storage.floats == expected);
}


/*
 * The target byte extent can become unrepresentable even when the source byte
 * extent still fits.
 *
 * Synthetic pointers are never dereferenced.
 */
unittest
{
    const elementCount =
        size_t.max / float.sizeof + 1;

    const relation =
        classifyConversionPhysicalRanges(
            cast(const(ubyte)*) 16,
            cast(float*) 32,
            elementCount
        );

    assert(
        relation
        == PhysicalByteRangeRelation.unrepresentable
    );
}


/*
 * Address-end overflow is also reported without dereferencing either pointer.
 */
unittest
{
    const relation =
        classifyConversionPhysicalRanges(
            cast(const(ubyte)*)
                (size_t.max - 1),
            cast(float*) 16,
            4
        );

    assert(
        relation
        == PhysicalByteRangeRelation.unrepresentable
    );
}


/*
 * Half-open ranges that meet exactly at one boundary do not overlap.
 *
 * For four samples the source occupies [16,20) and the float target starts at
 * 20, occupying [20,36).
 */
unittest
{
    const relation =
        classifyConversionPhysicalRanges(
            cast(const(ubyte)*) 16,
            cast(float*) 20,
            4
        );

    assert(
        relation
        == PhysicalByteRangeRelation.nonOverlapping
    );
}


/*
 * E5.4e.3 retained consumer integration.
 *
 * The float destination reaches the unchanged conversion dispatcher through:
 *
 *     OwnedByteResource
 *         -> RasterLease!float
 *         -> WritableRasterView!float
 *         -> RasterTargetPlane!float
 *         -> tryConvertUbyteToFloatContiguous1D
 *
 * Conversion semantics and invocation-local physical-range checking remain in
 * the existing dispatcher.
 */
unittest
{
    enum size_t width = 3;
    enum size_t height = 2;
    enum size_t elementCount =
        width * height;

    enum size_t sourceByteLength =
        elementCount * ubyte.sizeof;

    enum size_t targetByteLength =
        elementCount * float.sizeof;


    auto sourceMemory =
        cast(ubyte*) malloc(
            sourceByteLength
        );

    auto targetMemory =
        cast(float*) malloc(
            targetByteLength
        );

    assert(sourceMemory !is null);
    assert(targetMemory !is null);


    const ubyte[elementCount] sourceValues =
        [0, 1, 127, 128, 254, 255];


    foreach (index; 0 .. elementCount)
    {
        sourceMemory[index] =
            sourceValues[index];

        targetMemory[index] =
            -1.0f;
    }


    OwnedByteResource sourceResource;
    OwnedByteResource targetResource;

    assert(
        tryAdoptMallocResource(
            cast(void*) sourceMemory,
            sourceByteLength,
            sourceResource
        )
    );

    assert(
        tryAdoptMallocResource(
            cast(void*) targetMemory,
            targetByteLength,
            targetResource
        )
    );


    RasterLease!ubyte sourceLease;
    RasterLease!float targetLease;


    const PlaneByteLayout[1] sourceLayout =
    [
        PlaneByteLayout(
            0,
            width,
            1
        )
    ];

    const PlaneByteLayout[1] targetLayout =
    [
        PlaneByteLayout(
            0,
            width * float.sizeof,
            float.sizeof
        )
    ];


    const sourceImport =
        tryImportOwnedRaster!ubyte(
            sourceResource,
            sourceLayout[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            sourceLease
        );

    const targetImport =
        tryImportOwnedRaster!float(
            targetResource,
            targetLayout[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            targetLease
        );

    assert(sourceImport.ok);
    assert(targetImport.ok);

    assert(!sourceResource.ownsResource);
    assert(!targetResource.ownsResource);


    auto source =
        sourceLease.view();


    bool writableSuccess;

    auto writable =
        targetLease.tryWritableView(
            writableSuccess
        );

    assert(writableSuccess);


    bool targetSuccess;

    auto target =
        tryBorrowContiguousTarget(
            writable,
            0,
            targetSuccess
        );

    assert(targetSuccess);


    const result =
        tryConvertUbyteToFloatContiguous1D(
            source,
            0,
            target
        );

    assert(result.ok);

    assert(
        result.error
        == UbyteToFloatConversionError.none
    );


    auto readableTarget =
        targetLease.view();

    foreach (index; 0 .. elementCount)
    {
        float value;

        assert(
            readableTarget.trySample(
                0,
                index % width,
                index / width,
                value
            )
        );

        assert(
            value
            == cast(float) sourceValues[index]
        );
    }
}

}
