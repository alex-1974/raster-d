/++
    Shared compact one-plane raster allocation for allocating convenience APIs.

    This module is package-internal. It centralizes the retained storage path
    already qualified by tryTransformAllocated() so allocating conversion and
    future materializing wrappers do not duplicate owner/backing construction.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.compact_allocation;

import core.stdc.stdlib :
    free,
    malloc;

import std.algorithm.mutation :
    move;

import raster.backing :
    RasterLease;

import raster.byte_layout :
    PlaneByteLayout;

import raster.construction :
    constructRetainedRaster;

import raster.descriptor :
    PlaneDescriptor;

import raster.import_owned :
    tryImportOwnedRaster;

import raster.owned_resource :
    OwnedByteResource,
    tryAdoptMallocResource;

import raster.region :
    Region2D;

import raster.resource :
    ResourceEntry;


/++
    Internal compact-allocation failure category.
+/
package(raster)
enum CompactAllocationError : ubyte
{
    none,
    sizeOverflow,
    allocationFailed,
    backingConstructionFailed,
    internalFailure
}


/++
    Internal result for one compact one-plane retained allocation.
+/
package(raster)
struct CompactAllocationResult(T)
{
    CompactAllocationError error =
        CompactAllocationError.internalFailure;

    RasterLease!T lease;
}


/++
    Builds a genuine retained one-plane empty raster without pixel allocation.
+/
private
CompactAllocationResult!T allocateEmptyCompactRaster(T)(
    size_t width,
    size_t height
)
@trusted
{
    ResourceEntry[] resources;

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            null,
            0,
            1
        )
    ];

    RasterLease!T lease;

    const construction =
        constructRetainedRaster!T(
            resources,
            descriptors[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    CompactAllocationResult!T result;

    if (!construction.ok)
    {
        result.error =
            CompactAllocationError.backingConstructionFailed;

        return result;
    }

    result.error =
        CompactAllocationError.none;

    result.lease =
        move(lease);

    return result;
}


/++
    Allocates and retains one compact writable one-plane raster.

    Layout:
      resident origin 0,0
      sample stride   1
      row stride      width
      storage         one malloc-compatible allocation
+/
private
CompactAllocationResult!T allocateNonEmptyCompactRaster(T)(
    size_t width,
    size_t height
)
@trusted
{
    CompactAllocationResult!T result;

    if (
        width == 0
        || height == 0
    )
    {
        result.error =
            CompactAllocationError.internalFailure;

        return result;
    }

    if (
        width > size_t.max / height
    )
    {
        result.error =
            CompactAllocationError.sizeOverflow;

        return result;
    }

    const sampleCount =
        width * height;

    if (
        sampleCount
        > size_t.max / T.sizeof
    )
    {
        result.error =
            CompactAllocationError.sizeOverflow;

        return result;
    }

    if (
        width
        > size_t.max / T.sizeof
    )
    {
        result.error =
            CompactAllocationError.sizeOverflow;

        return result;
    }

    const rowByteStride =
        width * T.sizeof;

    if (
        rowByteStride
        > cast(size_t) ptrdiff_t.max
        || T.sizeof
            > cast(size_t) ptrdiff_t.max
    )
    {
        result.error =
            CompactAllocationError.sizeOverflow;

        return result;
    }

    const byteLength =
        sampleCount * T.sizeof;

    void* memory =
        malloc(byteLength);

    if (memory is null)
    {
        result.error =
            CompactAllocationError.allocationFailed;

        return result;
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
        free(memory);

        result.error =
            CompactAllocationError.internalFailure;

        return result;
    }

    const PlaneByteLayout[1] planes =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t) rowByteStride,
            cast(ptrdiff_t) T.sizeof
        )
    ];

    RasterLease!T lease;

    const imported =
        tryImportOwnedRaster!T(
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

    if (!imported.ok)
    {
        result.error =
            CompactAllocationError.backingConstructionFailed;

        return result;
    }

    result.error =
        CompactAllocationError.none;

    result.lease =
        move(lease);

    return result;
}


/++
    Allocates one compact retained one-plane raster.

    Empty geometry creates metadata-only retained storage.
+/
package(raster)
CompactAllocationResult!T allocateCompactRaster(T)(
    size_t width,
    size_t height
)
@safe
{
    if (
        width == 0
        || height == 0
    )
    {
        return allocateEmptyCompactRaster!T(
            width,
            height
        );
    }

    return allocateNonEmptyCompactRaster!T(
        width,
        height
    );
}
