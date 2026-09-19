/++
    Internal copy dispatch and source/target alias-relation checks.

    Source/target non-overlap is a relation between one concrete source plane
    and one concrete target. It is deliberately not represented as a property
    of RasterTargetPlane and is not accepted as an unchecked caller assertion.

    E4.3a established the checked source/target relation contract.

    E4.3b specializes the successful proven-non-overlap case with `memcpy`
    inside the same narrow trusted boundary. No compiler-specific no-alias
    attribute is part of the production contract.
+/
module imagery.raster.internal.copy_dispatch;

import core.stdc.string :
    memcpy;

import imagery.raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DByteOverlap;

import imagery.raster.internal.execution_layout :
    PlaneExecutionTraits;

import imagery.raster.internal.physical_range :
    PhysicalByteRangeRelation,
    classifyByteAddressRanges;

import imagery.raster.internal.target :
    RasterTargetPlane;

import imagery.raster.view :
    RasterView;

import imagery.raster.writable_view :
    WritableRasterView;


/++
    Failure category for checked non-overlapping contiguous copy.
+/
package(imagery.raster)
enum NonOverlappingCopyError : ubyte
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
    Result of checked non-overlapping contiguous copy.

    `.init` deliberately represents failure rather than success.
+/
package(imagery.raster)
struct NonOverlappingCopyResult
{
    NonOverlappingCopyError error =
        NonOverlappingCopyError.addressRangeUnrepresentable;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == NonOverlappingCopyError.none;
    }
}


private
NonOverlappingCopyResult copySuccess()
@safe
pure
nothrow
@nogc
{
    NonOverlappingCopyResult result;

    result.error =
        NonOverlappingCopyError.none;

    return result;
}


private
NonOverlappingCopyResult copyFailure(
    NonOverlappingCopyError error
)
@safe
pure
nothrow
@nogc
{
    NonOverlappingCopyResult result;

    result.error =
        error;

    return result;
}


/*
 * Outcome of checking and, when permitted, copying two non-empty flat
 * byte-address intervals.
 *
 * `copied` means that the non-overlap proof succeeded and the bytewise copy
 * has already completed.
 */
private
enum CheckedPhysicalCopyOutcome : ubyte
{
    overlapDetected,

    copied,

    unrepresentable
}


/++
    Checks two equally sized, non-empty contiguous T ranges and copies them
    when their complete physical byte intervals are provably non-overlapping.

    This remains the only trusted boundary in the checked-copy operation.

    Pointer values are converted to integer addresses so half-open physical
    byte intervals can be compared:

        [sourceStart, sourceEnd)
        [targetStart, targetEnd)

    The project already uses the same flat-address representation inside its
    retained-resource validation boundary.

    `memcpy` is reached only after proving that the intervals do not overlap.
    The flat-contiguous execution capability and target construction guarantee
    that byteLength bytes are reachable from both supplied bases.
+/
private
CheckedPhysicalCopyOutcome copyIfPhysicalRangesNonOverlapping(T)(
    scope const(T)* sourceBase,
    scope T* targetBase,
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
        > size_t.max / T.sizeof
    )
    {
        return CheckedPhysicalCopyOutcome.unrepresentable;
    }

    const byteLength =
        elementCount * T.sizeof;

    const sourceStart =
        cast(size_t) sourceBase;

    const targetStart =
        cast(size_t) targetBase;

    final switch (
        classifyByteAddressRanges(
            sourceStart,
            byteLength,
            targetStart,
            byteLength
        )
    )
    {
        case PhysicalByteRangeRelation.unrepresentable:
            return CheckedPhysicalCopyOutcome.unrepresentable;

        case PhysicalByteRangeRelation.overlapping:
            return CheckedPhysicalCopyOutcome.overlapDetected;

        case PhysicalByteRangeRelation.nonOverlapping:
        {
            memcpy(
                targetBase,
                sourceBase,
                byteLength
            );

            return CheckedPhysicalCopyOutcome.copied;
        }
    }
}


/++
    Converts validated source/target execution pointers to flat machine
    addresses and delegates exact same-type affine sample-byte classification
    to the safe relation layer.

    Pointer-to-integer conversion remains an operation-local trusted boundary.

    No pointer is dereferenced here.
+/
private
AffineByteOverlapRelation classifySameTypeAffinePhysicalRelation(T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    scope T* targetBase,
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
    assert(width != 0);
    assert(height != 0);

    return classifySameTypeAffine2DByteOverlap(
        width,
        height,

        cast(size_t) sourceBase,
        sourceRowStrideElements,
        sourceSampleStrideElements,

        cast(size_t) targetBase,
        targetRowStrideElements,
        targetSampleStrideElements,

        T.sizeof
    );
}


/++
    Scalar semantic execution for an already-approved affine same-type copy.

    All failure conditions that can occur for valid operands are established
    before entering this function.

    In particular:

    - logical shapes match;
    - both plane indices are valid;
    - the destination mapping is injective;
    - source and target sample bytes are physically disjoint.

    RasterView and WritableRasterView remain the semantic access boundaries.
    No new writable execution representation is introduced for E5.4f.5c.2.
+/
private
void copyApprovedAffine2D(T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!T target,
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
            T value;

            const readOk =
                source.trySample(
                    sourcePlaneIndex,
                    x,
                    y,
                    value
                );

            assert(readOk);


            const writeOk =
                target.trySetSample(
                    targetPlaneIndex,
                    x,
                    y,
                    value
                );

            assert(writeOk);
        }
    }
}


/++
    Copies one equally shaped source plane into one affine writable destination
    only after establishing the E5.4f bulk-write relation contract.

    Source self-aliasing is permitted.

    The destination finite mapping must be injective.

    Actual physical source/target sample-byte overlap is unsupported and is
    rejected before the first target write.

    The relation is checked in this order:

    - source plane index;
    - target plane index;
    - logical shape;
    - empty shape;
    - destination injectivity;
    - exact same-type physical sample-byte overlap;
    - scalar semantic execution.

    No caller-provided alias assertion is accepted.

    Successful classification does not create a persistent noalias or
    injectivity capability.
+/
package(imagery.raster)
NonOverlappingCopyResult tryCopyNonOverlappingAffine2D(T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!T target,
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
        return copyFailure(
            NonOverlappingCopyError.invalidPlaneIndex
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
        return copyFailure(
            NonOverlappingCopyError.invalidTargetPlaneIndex
        );
    }


    if (
        source.width != target.width
        || source.height != target.height
    )
    {
        return copyFailure(
            NonOverlappingCopyError.shapeMismatch
        );
    }


    if (source.empty)
        return copySuccess();


    if (
        !affine2DMappingIsInjective(
            target.width,
            target.height,
            targetRowStrideElements,
            targetSampleStrideElements
        )
    )
    {
        return copyFailure(
            NonOverlappingCopyError.nonInjectiveTarget
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
        classifySameTypeAffinePhysicalRelation(
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
            return copyFailure(
                NonOverlappingCopyError.overlapDetected
            );

        case AffineByteOverlapRelation.arithmeticFailure:
            return copyFailure(
                NonOverlappingCopyError.addressRangeUnrepresentable
            );

        case AffineByteOverlapRelation.disjoint:
        {
            copyApprovedAffine2D(
                source,
                sourcePlaneIndex,
                target,
                targetPlaneIndex
            );

            return copySuccess();
        }
    }
}


/++
    Copies one source plane into a contiguous target only after proving that
    their complete flat contiguous physical ranges do not overlap.

    The function does not accept a caller-supplied alias assertion.

    Preconditions are established internally in this order:

    - plane index must be valid;
    - source and target logical shapes must match;
    - empty matching shapes succeed without forming physical ranges;
    - the source must provide flat Contiguous 1D execution;
    - physical byte intervals must be representable;
    - source and target intervals must not overlap.

    Failure occurs before the first target write.

    E4.3b executes a direct bytewise copy only after the same E4.3a
    non-overlap proof succeeds. No caller-provided no-alias assertion is
    accepted and no compiler-specific restrict attribute is required.
+/
package(imagery.raster)
NonOverlappingCopyResult tryCopyNonOverlappingContiguous1D(T)(
    scope RasterView!T source,
    size_t planeIndex,
    scope RasterTargetPlane!T target
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
        return copyFailure(
            NonOverlappingCopyError.invalidPlaneIndex
        );
    }

    if (
        source.width != target.width
        || source.height != target.height
    )
    {
        return copyFailure(
            NonOverlappingCopyError.shapeMismatch
        );
    }

    /*
     * Matching empty shapes contain no reachable samples and therefore no
     * overlapping sample range requiring proof.
     */
    if (source.empty)
    {
        return copySuccess();
    }

    if (!traits.linearContiguous1D)
    {
        return copyFailure(
            NonOverlappingCopyError.unsupportedExecution
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
        copyIfPhysicalRangesNonOverlapping(
            sourceBase,
            targetBase,
            traits.flatElementCount
        )
    )
    {
        case CheckedPhysicalCopyOutcome.overlapDetected:
            return copyFailure(
                NonOverlappingCopyError.overlapDetected
            );

        case CheckedPhysicalCopyOutcome.copied:
            return copySuccess();

        case CheckedPhysicalCopyOutcome.unrepresentable:
            return copyFailure(
                NonOverlappingCopyError.addressRangeUnrepresentable
            );
    }
}


version (unittest)
{

import core.stdc.stdlib :
    malloc;

import imagery.raster.backing :
    RasterLease;

import imagery.raster.byte_layout :
    PlaneByteLayout;

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.import_owned :
    tryImportOwnedRaster;

import imagery.raster.internal.target :
    tryBorrowContiguousTarget;

import imagery.raster.owned_resource :
    OwnedByteResource,
    tryAdoptMallocResource;

import imagery.raster.region :
    Region2D;

import imagery.raster.resource :
    ResourceAccess,
    ResourceEntry;

import imagery.raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import imagery.raster.view :
    makeRasterViewAssumeValidated;

import imagery.raster.writable_view :
    tryMakeWritableRasterView;


/*
 * Exact affine relation accepts the E5.4f bounding-envelope false positive.
 *
 * Physical source samples occupy even byte addresses while target samples
 * occupy odd byte addresses in the same backing:
 *
 *     source: 0,2,4,6
 *     target: 1,3,5,7
 *
 * Their address envelopes overlap, but no actual sample byte overlaps.
 */
unittest
{
    ubyte[8] storage =
        [1, 0, 2, 0, 3, 0, 4, 0];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            0,
            2
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            storage.ptr + 1,
            0,
            2
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(
                0,
                0,
                4,
                1
            )
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!ubyte(
            resources[],
            targetDescriptors[],
            Region2D(
                0,
                0,
                4,
                1
            ),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryCopyNonOverlappingAffine2D(
            source,
            0,
            target,
            0
        );

    assert(result.ok);

    assert(
        storage
        == [1, 1, 2, 2, 3, 3, 4, 4]
    );
}


/*
 * Genuine affine source/target overlap is rejected before the first write.
 */
unittest
{
    ubyte[9] storage =
        [1, 91, 2, 92, 3, 93, 4, 94, 95];

    const original =
        storage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            0,
            2
        )
    ];

    const PlaneDescriptor[1] targetDescriptors =
    [
        PlaneDescriptor(
            storage.ptr + 2,
            0,
            2
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(
                0,
                0,
                4,
                1
            )
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!ubyte(
            resources[],
            targetDescriptors[],
            Region2D(
                0,
                0,
                4,
                1
            ),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryCopyNonOverlappingAffine2D(
            source,
            0,
            target,
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.overlapDetected
    );

    assert(storage == original);
}


/*
 * A writable but non-injective destination is rejected before any write.
 *
 * Target offsets:
 *
 *     0 1 2
 *     2 3 4
 *
 * Logical coordinates (2,0) and (0,1) alias the same sample.
 */
unittest
{
    ubyte[6] sourceStorage =
        [1, 2, 3, 4, 5, 6];

    ubyte[5] targetStorage =
        [9, 9, 9, 9, 9];

    const auto original =
        targetStorage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            targetStorage.ptr,
            targetStorage.length,
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
            Region2D(
                0,
                0,
                3,
                2
            )
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!ubyte(
            resources[],
            targetDescriptors[],
            Region2D(
                0,
                0,
                3,
                2
            ),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryCopyNonOverlappingAffine2D(
            source,
            0,
            target,
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.nonInjectiveTarget
    );

    assert(targetStorage == original);
}


/*
 * Negative destination sample stride is supported when the finite mapping is
 * injective and source/target storage is disjoint.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    ubyte[4] targetStorage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            targetStorage.ptr,
            targetStorage.length,
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
            targetStorage.ptr + 3,
            0,
            -1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(
                0,
                0,
                4,
                1
            )
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!ubyte(
            resources[],
            targetDescriptors[],
            Region2D(
                0,
                0,
                4,
                1
            ),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryCopyNonOverlappingAffine2D(
            source,
            0,
            target,
            0
        );

    assert(result.ok);

    assert(
        targetStorage
        == [4, 3, 2, 1]
    );
}


/*
 * Source self-aliasing remains permitted.
 *
 * Every logical source coordinate reads the same physical sample. The
 * destination is injective and physically disjoint.
 */
unittest
{
    ubyte[1] sourceStorage =
        [77];

    ubyte[6] targetStorage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            targetStorage.ptr,
            targetStorage.length,
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
            Region2D(
                0,
                0,
                3,
                2
            )
        );

    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto target =
        tryMakeWritableRasterView!ubyte(
            resources[],
            targetDescriptors[],
            Region2D(
                0,
                0,
                3,
                2
            ),
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    const result =
        tryCopyNonOverlappingAffine2D(
            source,
            0,
            target,
            0
        );

    assert(result.ok);

    assert(
        targetStorage
        == [77, 77, 77, 77, 77, 77]
    );
}


/*
 * Distinct contiguous source and target ranges are proved non-overlapping and
 * copied through the checked memcpy path.
 */
unittest
{
    ushort[6] sourceStorage =
        [10, 20, 30, 40, 50, 60];

    ushort[6] targetStorage;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            3,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ushort(
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
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(result.ok);
    assert(targetStorage == sourceStorage);
}


/*
 * Partial physical overlap is detected before the first target write.
 */
unittest
{
    ubyte[5] storage =
        [1, 2, 3, 4, 99];

    const original =
        storage;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
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
            storage[1 .. 5],
            4,
            1,
            success
        );

    assert(success);

    const result =
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.overlapDetected
    );

    assert(storage == original);
}


/*
 * Exact source/target overlap is likewise rejected.
 */
unittest
{
    uint[4] storage =
        [11, 22, 33, 44];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            4,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!uint(
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
            storage[],
            4,
            1,
            success
        );

    assert(success);

    const result =
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.overlapDetected
    );
}


/*
 * Shape mismatch is reported before alias analysis or writes.
 */
unittest
{
    ubyte[6] sourceStorage =
        [1, 2, 3, 4, 5, 6];

    ubyte[4] targetStorage =
        [9, 9, 9, 9];

    const original =
        targetStorage;

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
            2,
            2,
            success
        );

    assert(success);

    const result =
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.shapeMismatch
    );

    assert(targetStorage == original);
}


/*
 * A padded Canonical source is valid raster execution, but it is not the flat
 * contiguous capability required by this E4.3 path.
 */
unittest
{
    ubyte[6] sourceStorage =
        [1, 2, 99, 3, 4, 99];

    ubyte[4] targetStorage;

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
                2,
                2
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
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.unsupportedExecution
    );
}


/*
 * Empty matching shapes succeed without requiring flat-contiguous execution
 * and without forming source or target sample pointers.
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

    ubyte[] targetStorage;

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
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(result.ok);
}


/*
 * Invalid plane index is reported before execution or alias analysis.
 */
unittest
{
    ubyte[4] sourceStorage;
    ubyte[4] targetStorage;

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
        tryCopyNonOverlappingContiguous1D(
            source,
            1,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.invalidPlaneIndex
    );
}


/*
 * Half-open adjacent intervals are non-overlapping and may therefore be
 * copied byte-for-byte.
 */
unittest
{
    ubyte[8] storage =
        [1, 2, 3, 4, 0, 0, 0, 0];

    const relation =
        copyIfPhysicalRangesNonOverlapping(
            storage.ptr,
            storage.ptr + 4,
            4
        );

    assert(
        relation
        == CheckedPhysicalCopyOutcome.copied
    );

    assert(
        storage[4 .. 8]
        == storage[0 .. 4]
    );
}


/*
 * Address-end overflow is rejected instead of wrapping the interval.
 *
 * Synthetic pointer values are never dereferenced.
 */
unittest
{
    const source =
        cast(const(ubyte)*)(size_t.max - 1);

    auto target =
        cast(ubyte*) 16;

    const relation =
        copyIfPhysicalRangesNonOverlapping(
            source,
            target,
            4
        );

    assert(
        relation
        == CheckedPhysicalCopyOutcome.unrepresentable
    );
}


/*
 * E5.4e.3 retained consumer integration.
 *
 * The destination reaches the existing checked-copy dispatcher through the
 * complete retained writable chain:
 *
 *     OwnedByteResource
 *         -> RasterLease
 *         -> WritableRasterView
 *         -> RasterTargetPlane
 *         -> tryCopyNonOverlappingContiguous1D
 *
 * The dispatcher itself is unchanged.
 */
unittest
{
    enum size_t width = 3;
    enum size_t height = 2;
    enum size_t elementCount =
        width * height;

    enum size_t byteLength =
        elementCount * ushort.sizeof;


    auto sourceMemory =
        cast(ushort*) malloc(byteLength);

    auto targetMemory =
        cast(ushort*) malloc(byteLength);

    assert(sourceMemory !is null);
    assert(targetMemory !is null);


    foreach (index; 0 .. elementCount)
    {
        sourceMemory[index] =
            cast(ushort)((index + 1) * 10);

        targetMemory[index] = 0;
    }


    OwnedByteResource sourceResource;
    OwnedByteResource targetResource;

    assert(
        tryAdoptMallocResource(
            cast(void*) sourceMemory,
            byteLength,
            sourceResource
        )
    );

    assert(
        tryAdoptMallocResource(
            cast(void*) targetMemory,
            byteLength,
            targetResource
        )
    );


    RasterLease!ushort sourceLease;
    RasterLease!ushort targetLease;


    const PlaneByteLayout[1] layout =
    [
        PlaneByteLayout(
            0,
            width * ushort.sizeof,
            ushort.sizeof
        )
    ];


    const sourceImport =
        tryImportOwnedRaster!ushort(
            sourceResource,
            layout[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            sourceLease
        );

    const targetImport =
        tryImportOwnedRaster!ushort(
            targetResource,
            layout[],
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
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(result.ok);


    auto readableTarget =
        targetLease.view();

    foreach (index; 0 .. elementCount)
    {
        ushort value;

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
            == cast(ushort)((index + 1) * 10)
        );
    }
}


/*
 * Deriving RasterTargetPlane from WritableRasterView must not manufacture a
 * no-alias guarantee.
 *
 * A read view and writable target derived from the same retained backing are
 * legal capabilities. Their concrete physical relation remains an
 * invocation-local property of the checked-copy dispatcher.
 *
 * Therefore this operation reaches the existing overlap check and fails
 * without modifying storage.
 */
unittest
{
    enum size_t width = 4;
    enum size_t height = 1;
    enum size_t byteLength =
        width * ubyte.sizeof;


    auto memory =
        cast(ubyte*) malloc(byteLength);

    assert(memory !is null);

    memory[0] = 1;
    memory[1] = 2;
    memory[2] = 3;
    memory[3] = 4;


    OwnedByteResource resource;

    assert(
        tryAdoptMallocResource(
            cast(void*) memory,
            byteLength,
            resource
        )
    );


    RasterLease!ubyte lease;


    const PlaneByteLayout[1] layout =
    [
        PlaneByteLayout(
            0,
            width,
            1
        )
    ];


    const imported =
        tryImportOwnedRaster!ubyte(
            resource,
            layout[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    assert(imported.ok);
    assert(!resource.ownsResource);


    auto source =
        lease.view();


    bool writableSuccess;

    auto writable =
        lease.tryWritableView(
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
        tryCopyNonOverlappingContiguous1D(
            source,
            0,
            target
        );

    assert(!result.ok);

    assert(
        result.error
        == NonOverlappingCopyError.overlapDetected
    );


    auto verify =
        lease.view();

    ubyte value;

    assert(
        verify.trySample(
            0,
            0,
            0,
            value
        )
    );

    assert(value == 1);

    assert(
        verify.trySample(
            0,
            1,
            0,
            value
        )
    );

    assert(value == 2);

    assert(
        verify.trySample(
            0,
            2,
            0,
            value
        )
    );

    assert(value == 3);

    assert(
        verify.trySample(
            0,
            3,
            0,
            value
        )
    );

    assert(value == 4);
}

}
