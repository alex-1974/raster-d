module raster.internal.block_resolution;

import raster.backing :
    RasterLease;

import raster.region :
    Region2D;

import raster.internal.retained_store :
    RetainedStoreInsertResult;

import raster.writable_view :
    WritableRasterView;


package(raster)
struct RetainedBlockDescriptor(Key)
{
    Key key;

    Region2D logicalRegion;
}


package(raster)
enum DependencyBlockResolveError : ubyte
{
    none,

    invalidCoverage,

    destinationRegionMismatch,

    sourceFailure,

    invalidRetainedValue,

    blockShapeMismatch,

    planeCountMismatch,

    sampleTransferFailure
}


static assert(
    DependencyBlockResolveError.init
    == DependencyBlockResolveError.none
);


package(raster)
struct DependencyBlockResolveStats
{
    size_t retainedHits;

    size_t sourceMisses;

    size_t storeInsertions;

    size_t storeInsertionRejections;
}


private
bool tryIntersection(
    Region2D lhs,
    Region2D rhs,
    out Region2D intersection
)
@safe
pure
nothrow
@nogc
{
    intersection =
        Region2D.init;

    if (
        !lhs.hasRepresentableExtent()
        || !rhs.hasRepresentableExtent()
    )
    {
        return false;
    }

    const lhsEndX =
        lhs.x + lhs.width;

    const lhsEndY =
        lhs.y + lhs.height;

    const rhsEndX =
        rhs.x + rhs.width;

    const rhsEndY =
        rhs.y + rhs.height;

    const startX =
        lhs.x > rhs.x
        ? lhs.x
        : rhs.x;

    const startY =
        lhs.y > rhs.y
        ? lhs.y
        : rhs.y;

    const endX =
        lhsEndX < rhsEndX
        ? lhsEndX
        : rhsEndX;

    const endY =
        lhsEndY < rhsEndY
        ? lhsEndY
        : rhsEndY;

    if (
        endX <= startX
        || endY <= startY
    )
    {
        intersection =
            Region2D(
                startX,
                startY,
                0,
                0
            );

        return true;
    }

    intersection =
        Region2D(
            startX,
            startY,
            endX - startX,
            endY - startY
        );

    return true;
}


private
bool tryArea(
    Region2D region,
    out size_t area
)
@safe
pure
nothrow
@nogc
{
    area = 0;

    if (region.empty())
    {
        return true;
    }

    if (
        region.height
        > size_t.max / region.width
    )
    {
        return false;
    }

    area =
        region.width
        * region.height;

    return true;
}


private
bool hasExactDisjointCoverage(Key)(
    Region2D logicalDependency,
    scope RetainedBlockDescriptor!Key[] blocks
)
@safe
pure
nothrow
@nogc
{
    if (!logicalDependency.hasRepresentableExtent())
    {
        return false;
    }

    if (logicalDependency.empty())
    {
        return true;
    }

    size_t requiredArea;

    if (
        !tryArea(
            logicalDependency,
            requiredArea
        )
    )
    {
        return false;
    }

    size_t coveredArea;

    foreach (i, ref block; blocks)
    {
        if (
            !block.logicalRegion
                .hasRepresentableExtent()
        )
        {
            return false;
        }

        Region2D clipped;

        if (
            !tryIntersection(
                logicalDependency,
                block.logicalRegion,
                clipped
            )
        )
        {
            return false;
        }

        size_t clippedArea;

        if (!tryArea(clipped, clippedArea))
        {
            return false;
        }

        if (
            clippedArea
            > size_t.max - coveredArea
        )
        {
            return false;
        }

        coveredArea +=
            clippedArea;

        if (clipped.empty())
        {
            continue;
        }

        foreach (
            j;
            i + 1 .. blocks.length
        )
        {
            if (
                !blocks[j].logicalRegion
                    .hasRepresentableExtent()
            )
            {
                return false;
            }

            Region2D otherClipped;

            if (
                !tryIntersection(
                    logicalDependency,
                    blocks[j].logicalRegion,
                    otherClipped
                )
            )
            {
                return false;
            }

            if (otherClipped.empty())
            {
                continue;
            }

            Region2D overlap;

            if (
                !tryIntersection(
                    clipped,
                    otherClipped,
                    overlap
                )
            )
            {
                return false;
            }

            if (!overlap.empty())
            {
                return false;
            }
        }
    }

    return
        coveredArea
        == requiredArea;
}


private
bool transferIntersection(T)(
    Region2D logicalDependency,
    Region2D logicalBlock,
    Region2D intersection,
    ref RasterLease!T lease,
    scope ref WritableRasterView!T destination
)
@safe
{
    auto source =
        lease.view();

    const endY =
        intersection.y
        + intersection.height;

    const endX =
        intersection.x
        + intersection.width;

    foreach (plane; 0 .. source.planeCount)
    {
        foreach (
            logicalY;
            intersection.y .. endY
        )
        {
            foreach (
                logicalX;
                intersection.x .. endX
            )
            {
                T value;

                if (
                    !source.trySample(
                        plane,
                        logicalX - logicalBlock.x,
                        logicalY - logicalBlock.y,
                        value
                    )
                )
                {
                    return false;
                }

                if (
                    !destination.trySetSample(
                        plane,
                        logicalX - logicalDependency.x,
                        logicalY - logicalDependency.y,
                        value
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


package(raster)
bool tryResolveDependencyBlocks(
    T,
    Key,
    Store,
    Source
)(
    Region2D logicalDependency,
    scope RetainedBlockDescriptor!Key[] blocks,
    ref Store store,
    ref Source source,
    scope ref WritableRasterView!T destination,
    out DependencyBlockResolveStats stats,
    out DependencyBlockResolveError error
)
@safe
{
    stats =
        DependencyBlockResolveStats.init;

    error =
        DependencyBlockResolveError.none;

    if (
        !hasExactDisjointCoverage(
            logicalDependency,
            blocks
        )
    )
    {
        error =
            DependencyBlockResolveError.invalidCoverage;

        return false;
    }

    const expectedDestination =
        Region2D(
            0,
            0,
            logicalDependency.width,
            logicalDependency.height
        );

    if (
        destination.region
        != expectedDestination
    )
    {
        error =
            DependencyBlockResolveError.destinationRegionMismatch;

        return false;
    }

    if (logicalDependency.empty())
    {
        return true;
    }

    foreach (ref block; blocks)
    {
        Region2D intersection;

        if (
            !tryIntersection(
                logicalDependency,
                block.logicalRegion,
                intersection
            )
        )
        {
            error =
                DependencyBlockResolveError.invalidCoverage;

            return false;
        }

        if (intersection.empty())
        {
            continue;
        }

        RasterLease!T lease;

        const retainedHit =
            store.tryAcquire(
                block.key,
                lease
            );

        if (retainedHit)
        {
            ++stats.retainedHits;
        }
        else
        {
            ++stats.sourceMisses;

            if (
                !source.materializeRetained(
                    block.logicalRegion,
                    lease
                )
            )
            {
                error =
                    DependencyBlockResolveError.sourceFailure;

                return false;
            }
        }

        if (!lease.hasBacking)
        {
            error =
                DependencyBlockResolveError.invalidRetainedValue;

            return false;
        }

        auto sourceView =
            lease.view();

        if (
            sourceView.width
                != block.logicalRegion.width
            || sourceView.height
                != block.logicalRegion.height
        )
        {
            error =
                DependencyBlockResolveError.blockShapeMismatch;

            return false;
        }

        if (
            sourceView.planeCount
            != destination.planeCount
        )
        {
            error =
                DependencyBlockResolveError.planeCountMismatch;

            return false;
        }

        if (
            !transferIntersection(
                logicalDependency,
                block.logicalRegion,
                intersection,
                lease,
                destination
            )
        )
        {
            error =
                DependencyBlockResolveError.sampleTransferFailure;

            return false;
        }

        if (!retainedHit)
        {
            final switch (
                store.insertOwned(
                    block.key,
                    lease
                )
            )
            {
                case RetainedStoreInsertResult.inserted:
                    ++stats.storeInsertions;
                    break;

                case RetainedStoreInsertResult.duplicateKey:
                case RetainedStoreInsertResult.invalidRetainedValue:
                case RetainedStoreInsertResult.retainedByteBudgetExceeded:
                case RetainedStoreInsertResult.entryCapacityExceeded:
                    ++stats.storeInsertionRejections;
                    break;
            }
        }
    }

    return true;
}
