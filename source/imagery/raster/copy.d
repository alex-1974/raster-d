/++
    Public raster copy operations.

    This module exposes logical raster-copy semantics only.

    Execution layouts, contiguous targets, physical-address classifiers,
    checked-wide relation arithmetic and kernel selection remain internal.
+/
module imagery.raster.copy;

import imagery.raster.internal.copy_dispatch :
    SameTypeRasterCopyError,
    copySameTypeRasterPlane;

import imagery.raster.view :
    RasterView;

import imagery.raster.writable_view :
    WritableRasterView;


/++
    Semantic failure category for `tryCopyRasterPlane`.

    `.none` means that no semantic request failure occurred.

    Execution-path availability and internal arithmetic-carrier states are not
    public errors.
+/
enum RasterCopyError : ubyte
{
    none,

    invalidSourcePlane,

    invalidDestinationPlane,

    shapeMismatch,

    nonInjectiveDestination,

    sourceDestinationOverlap
}


static assert(
    RasterCopyError.init
    == RasterCopyError.none
);


/++
    Copies one logical source plane to the corresponding logical samples of one
    equally shaped writable destination plane.

    `source` and `destination` use the same raster sample type.

    A matching empty source/destination shape succeeds as a no-op.

    The destination mapping must be injective.

    Source self-aliasing is permitted. Source and destination may share backing
    storage when their actually reachable sample bytes are disjoint.

    Actual source/destination sample-byte overlap is rejected before the first
    destination write. This operation does not provide snapshot or memmove
    semantics.

    Returns true on success and false on a semantic request failure.

    `error` is reset to `RasterCopyError.none` on entry. On false it identifies
    exactly one of:

    - invalid source plane;
    - invalid destination plane;
    - shape mismatch;
    - non-injective destination mapping;
    - actual source/destination sample-byte overlap.

    Every validated resident execution layout is semantically supported.
    Execution-layout selection and fallback behavior remain internal.

    The operation is allocation-free and retains neither operand.
+/
bool tryCopyRasterPlane(T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterCopyError error
)
@safe
nothrow
@nogc
{
    error =
        RasterCopyError.none;

    final switch (
        copySameTypeRasterPlane(
            source,
            sourcePlaneIndex,
            destination,
            destinationPlaneIndex
        )
    )
    {
        case SameTypeRasterCopyError.none:
            return true;

        case SameTypeRasterCopyError.invalidSourcePlane:
            error =
                RasterCopyError.invalidSourcePlane;
            return false;

        case SameTypeRasterCopyError.invalidDestinationPlane:
            error =
                RasterCopyError.invalidDestinationPlane;
            return false;

        case SameTypeRasterCopyError.shapeMismatch:
            error =
                RasterCopyError.shapeMismatch;
            return false;

        case SameTypeRasterCopyError.nonInjectiveDestination:
            error =
                RasterCopyError.nonInjectiveDestination;
            return false;

        case SameTypeRasterCopyError.sourceDestinationOverlap:
            error =
                RasterCopyError.sourceDestinationOverlap;
            return false;
    }
}


version (unittest)
{

import imagery.raster.descriptor :
    PlaneDescriptor;

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


private
WritableRasterView!ubyte makeWritableTestView(
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
        tryMakeWritableRasterView!ubyte(
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


unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    ubyte[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterCopyError error =
        RasterCopyError.shapeMismatch;

    assert(
        tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterCopyError.none);
    assert(destinationStorage == sourceStorage);
}


unittest
{
    RasterView!ubyte source;
    WritableRasterView!ubyte destination;

    RasterCopyError error;

    assert(
        !tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterCopyError.invalidSourcePlane
    );
}


unittest
{
    ubyte[1] sourceStorage = [9];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            1,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    WritableRasterView!ubyte destination;

    RasterCopyError error;

    assert(
        !tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterCopyError.invalidDestinationPlane
    );
}


unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    ubyte[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 2)
        );

    RasterCopyError error;

    assert(
        !tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterCopyError.shapeMismatch
    );

    const ubyte[4] expectedDestination;

    assert(
        destinationStorage
        == expectedDestination
    );
}


unittest
{
    ubyte[2] sourceStorage =
        [5, 6];

    ubyte[1] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            0,
            0
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterCopyError error;

    assert(
        !tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterCopyError.nonInjectiveDestination
    );

    assert(destinationStorage[0] == 0);
}


unittest
{
    ubyte[4] storage =
        [10, 20, 30, 40];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(0, 0, 2, 2)
        );

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            descriptors[],
            Region2D(0, 0, 2, 2)
        );

    const before =
        storage;

    RasterCopyError error;

    assert(
        !tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterCopyError.sourceDestinationOverlap
    );

    assert(storage == before);
}


unittest
{
    ubyte[1] sourceStorage = [7];
    ubyte[1] destinationStorage = [3];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            1,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            1,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    RasterCopyError error =
        RasterCopyError.shapeMismatch;

    assert(
        tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterCopyError.none);
    assert(destinationStorage[0] == 3);
}


/*
 * Shared retained backing is permitted when the actually reachable source and
 * destination sample bytes are disjoint.
 *
 * Both operands are flat contiguous here, so this also exercises the checked
 * memcpy specialization through the stable public wrapper.
 */
unittest
{
    ubyte[8] storage =
        [1, 2, 3, 4, 0, 0, 0, 0];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            storage.ptr + 4,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterCopyError error;

    assert(
        tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterCopyError.none);
    assert(storage[4 .. 8] == storage[0 .. 4]);
}


/*
 * A valid negative-stride destination is semantically supported.
 *
 * This exercises the public wrapper through the general affine path rather
 * than requiring flat contiguous execution.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    ubyte[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr + 3,
            -2,
            -1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterCopyError error;

    assert(
        tryCopyRasterPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterCopyError.none);

    assert(
        destinationStorage
        == [4, 3, 2, 1]
    );
}

} // version (unittest)
