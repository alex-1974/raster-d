module raster.internal.streaming_equivalence_test;

version (unittest)
{

import core.stdc.stdlib : malloc;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster;

import raster.internal.block_resolution :
    DependencyBlockResolveError,
    DependencyBlockResolveStats,
    RetainedBlockDescriptor,
    tryResolveDependencyBlocks;

import raster.internal.dependency :
    ContextDeficit,
    DependencyMargins;

import raster.internal.materialization_plan :
    RequestMaterializationPlan,
    tryPlanRequestMaterialization;

import raster.internal.residency :
    ResidencyBudget;

import raster.internal.retained_store :
    RetainedRasterStore;


enum size_t cacheBlockWidth = 16;
enum size_t cacheBlockHeight = 12;


private
struct TestKey
{
    Region2D region;
}


private
size_t hashKey(
    ref const TestKey key
)
@safe pure nothrow @nogc
{
    size_t state = key.region.x;

    state ^=
        key.region.y
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.width
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.height
        + (state << 6)
        + (state >> 2);

    return state;
}


private
bool sameKey(
    ref const TestKey lhs,
    ref const TestKey rhs
)
@safe pure nothrow @nogc
{
    return lhs == rhs;
}


private
alias Store =
    RetainedRasterStore!(
        ubyte,
        TestKey,
        128,
        hashKey,
        sameKey
    );


private
ubyte proceduralValue(
    size_t logicalX,
    size_t logicalY
)
@safe pure nothrow @nogc
{
    const x =
        cast(uint) (logicalX % 251);

    const y =
        cast(uint) (logicalY % 251);

    return
        cast(ubyte)(
            (
                x * 17
                + y * 29
                + (x ^ y) * 3
            )
            % 251
        );
}


private
bool contains(
    Region2D outer,
    Region2D inner
)
@safe pure nothrow @nogc
{
    if (
        !outer.hasRepresentableExtent()
        || !inner.hasRepresentableExtent()
    )
    {
        return false;
    }

    return
        inner.x >= outer.x
        && inner.y >= outer.y
        && inner.x + inner.width
            <= outer.x + outer.width
        && inner.y + inner.height
            <= outer.y + outer.height;
}


private
bool makeLease(
    Region2D residentRegion,
    out RasterLease!ubyte lease
)
@trusted
{
    lease =
        RasterLease!ubyte.init;

    if (
        residentRegion.empty()
        || !residentRegion.hasRepresentableExtent()
        || residentRegion.height
            > size_t.max / residentRegion.width
    )
    {
        return false;
    }

    const byteLength =
        residentRegion.width
        * residentRegion.height;

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
                    cast(ptrdiff_t) residentRegion.width,
                    1
                )
            ],
            Region2D(
                0,
                0,
                residentRegion.width,
                residentRegion.height
            ),
            lease
        );

    return result.ok;
}


private
struct ProceduralSource
{
    Region2D logicalExtent;

    size_t providerBlockWidth = 13;

    size_t providerBlockHeight = 7;

    size_t calls;


    bool materializeRetained(
        Region2D logicalRegion,
        out RasterLease!ubyte lease
    )
    @trusted
    {
        lease =
            RasterLease!ubyte.init;

        if (
            logicalRegion.empty()
            || !contains(
                logicalExtent,
                logicalRegion
            )
        )
        {
            return false;
        }

        ++calls;

        if (
            !makeLease(
                logicalRegion,
                lease
            )
        )
        {
            return false;
        }

        bool writableOk;

        scope auto writable =
            lease.tryWritableView(
                writableOk
            );

        if (!writableOk)
        {
            return false;
        }

        foreach (y; 0 .. logicalRegion.height)
        {
            foreach (x; 0 .. logicalRegion.width)
            {
                if (
                    !writable.trySetSample(
                        0,
                        x,
                        y,
                        proceduralValue(
                            logicalRegion.x + x,
                            logicalRegion.y + y
                        )
                    )
                )
                {
                    return false;
                }
            }
        }

        return true;
    }
}


private
RetainedBlockDescriptor!TestKey[]
makeBlocks(
    Region2D logicalExtent,
    Region2D dependency
)
@safe
{
    RetainedBlockDescriptor!TestKey[] result;

    if (
        dependency.empty()
        || !contains(
            logicalExtent,
            dependency
        )
    )
    {
        return result;
    }

    const extentRight =
        logicalExtent.x
        + logicalExtent.width;

    const extentBottom =
        logicalExtent.y
        + logicalExtent.height;

    const relativeX =
        dependency.x
        - logicalExtent.x;

    const relativeY =
        dependency.y
        - logicalExtent.y;

    size_t blockY =
        dependency.y
        - (
            relativeY
            % cacheBlockHeight
        );

    const firstX =
        dependency.x
        - (
            relativeX
            % cacheBlockWidth
        );

    const dependencyRight =
        dependency.x
        + dependency.width;

    const dependencyBottom =
        dependency.y
        + dependency.height;

    while (blockY < dependencyBottom)
    {
        size_t blockX =
            firstX;

        const blockHeight =
            blockY + cacheBlockHeight
                <= extentBottom
            ? cacheBlockHeight
            : extentBottom - blockY;

        while (blockX < dependencyRight)
        {
            const blockWidth =
                blockX + cacheBlockWidth
                    <= extentRight
                ? cacheBlockWidth
                : extentRight - blockX;

            const region =
                Region2D(
                    blockX,
                    blockY,
                    blockWidth,
                    blockHeight
                );

            result ~=
                RetainedBlockDescriptor!TestKey(
                    TestKey(region),
                    region
                );

            blockX +=
                blockWidth;
        }

        blockY +=
            blockHeight;
    }

    return result;
}


private
size_t area(
    Region2D region
)
@safe pure nothrow @nogc
{
    assert(
        region.empty()
        || region.height
            <= size_t.max / region.width
    );

    return
        region.width
        * region.height;
}


private
size_t maxBlockBytes(
    scope RetainedBlockDescriptor!TestKey[] blocks
)
@safe pure nothrow @nogc
{
    size_t result;

    foreach (ref const block; blocks)
    {
        const bytes =
            area(
                block.logicalRegion
            );

        if (bytes > result)
        {
            result = bytes;
        }
    }

    return result;
}


private
ubyte kernel3x3(
    ubyte a00,
    ubyte a01,
    ubyte a02,
    ubyte a10,
    ubyte a11,
    ubyte a12,
    ubyte a20,
    ubyte a21,
    ubyte a22
)
@safe pure nothrow @nogc
{
    const uint weighted =
          cast(uint) a00
        + cast(uint) a01 * 2
        + cast(uint) a02 * 3
        + cast(uint) a10 * 5
        + cast(uint) a11 * 7
        + cast(uint) a12 * 11
        + cast(uint) a20 * 13
        + cast(uint) a21 * 17
        + cast(uint) a22 * 19;

    return
        cast(ubyte)(
            weighted % 251
        );
}


private
bool executeKernel(
    ref RasterLease!ubyte dependencyLease,
    RequestMaterializationPlan plan,
    out ubyte[] output
)
@safe
{
    output = null;

    if (
        plan.residentOutput.empty()
        || plan.dependency.contextDeficit
            != ContextDeficit.init
    )
    {
        return false;
    }

    const count =
        area(
            plan.residentOutput
        );

    output =
        new ubyte[count];

    auto input =
        dependencyLease.view();

    size_t outputIndex;

    foreach (y; 0 .. plan.residentOutput.height)
    {
        const centerY =
            plan.residentOutput.y
            + y;

        foreach (x; 0 .. plan.residentOutput.width)
        {
            const centerX =
                plan.residentOutput.x
                + x;

            ubyte[9] values;

            size_t index;

            foreach (dy; 0 .. 3)
            {
                foreach (dx; 0 .. 3)
                {
                    if (
                        !input.trySample(
                            0,
                            centerX + dx - 1,
                            centerY + dy - 1,
                            values[index]
                        )
                    )
                    {
                        return false;
                    }

                    ++index;
                }
            }

            output[outputIndex++] =
                kernel3x3(
                    values[0],
                    values[1],
                    values[2],
                    values[3],
                    values[4],
                    values[5],
                    values[6],
                    values[7],
                    values[8]
                );
        }
    }

    return
        outputIndex
        == output.length;
}


private
struct TaskExecution
{
    bool ok;

    ubyte[] output;

    DependencyBlockResolveStats resolveStats;

    size_t admittedBytes;
}


private
TaskExecution executeTask(
    Region2D logicalExtent,
    Region2D outputTask,
    ref Store store,
    ref ProceduralSource source,
    ref ResidencyBudget budget
)
@safe
{
    TaskExecution result;

    RequestMaterializationPlan plan;

    if (
        !tryPlanRequestMaterialization(
            logicalExtent,
            outputTask,
            DependencyMargins(
                1,
                1,
                1,
                1
            ),
            plan
        )
        || plan.dependency.contextDeficit
            != ContextDeficit.init
    )
    {
        return result;
    }

    auto blocks =
        makeBlocks(
            logicalExtent,
            plan.dependency.validInput
        );

    const requiredBytes =
        area(plan.residentInput)
        + maxBlockBytes(blocks);

    if (
        !budget.tryAdmit(
            requiredBytes
        )
    )
    {
        return result;
    }

    result.admittedBytes =
        requiredBytes;

    RasterLease!ubyte dependencyLease;

    if (
        !makeLease(
            plan.residentInput,
            dependencyLease
        )
    )
    {
        assert(
            budget.tryRelease(
                requiredBytes
            )
        );

        return result;
    }

    bool writableOk;

    scope auto destination =
        dependencyLease.tryWritableView(
            writableOk
        );

    if (!writableOk)
    {
        assert(
            budget.tryRelease(
                requiredBytes
            )
        );

        return result;
    }

    DependencyBlockResolveError resolveError;

    if (
        !tryResolveDependencyBlocks(
            plan.dependency.validInput,
            blocks,
            store,
            source,
            destination,
            result.resolveStats,
            resolveError
        )
        || resolveError
            != DependencyBlockResolveError.none
        || !executeKernel(
            dependencyLease,
            plan,
            result.output
        )
    )
    {
        assert(
            budget.tryRelease(
                requiredBytes
            )
        );

        return result;
    }

    assert(
        budget.tryRelease(
            requiredBytes
        )
    );

    result.ok = true;

    return result;
}


private
bool validateDecomposition(
    Region2D requestedOutput,
    scope Region2D[] tasks
)
@safe
{
    if (
        requestedOutput.empty()
        || area(requestedOutput) > 100_000
    )
    {
        return false;
    }

    auto coverage =
        new ubyte[
            area(requestedOutput)
        ];

    foreach (task; tasks)
    {
        if (
            task.empty()
            || !contains(
                requestedOutput,
                task
            )
        )
        {
            return false;
        }

        foreach (y; 0 .. task.height)
        {
            foreach (x; 0 .. task.width)
            {
                const relativeX =
                    task.x
                    - requestedOutput.x
                    + x;

                const relativeY =
                    task.y
                    - requestedOutput.y
                    + y;

                const index =
                    relativeY
                    * requestedOutput.width
                    + relativeX;

                if (coverage[index] != 0)
                {
                    return false;
                }

                coverage[index] = 1;
            }
        }
    }

    foreach (covered; coverage)
    {
        if (covered != 1)
        {
            return false;
        }
    }

    return true;
}


private
struct StreamExecution
{
    bool ok;

    ubyte[] output;

    size_t peakAdmittedBytes;

    size_t retainedHits;

    size_t sourceMisses;

    size_t storeInsertions;

    size_t storeInsertionRejections;

    size_t sourceCalls;

    size_t retainedStoreBytes;
}


private
StreamExecution executeDecomposition(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope Region2D[] tasks
)
@safe
{
    StreamExecution result;

    if (
        !validateDecomposition(
            requestedOutput,
            tasks
        )
    )
    {
        return result;
    }

    result.output =
        new ubyte[
            area(requestedOutput)
        ];

    Store store =
        Store(100_000);

    ProceduralSource source =
        ProceduralSource(
            logicalExtent
        );

    ResidencyBudget budget =
        ResidencyBudget(
            100_000
        );

    foreach (task; tasks)
    {
        auto execution =
            executeTask(
                logicalExtent,
                task,
                store,
                source,
                budget
            );

        if (!execution.ok)
        {
            return StreamExecution.init;
        }

        if (
            execution.admittedBytes
            > result.peakAdmittedBytes
        )
        {
            result.peakAdmittedBytes =
                execution.admittedBytes;
        }

        result.retainedHits +=
            execution.resolveStats.retainedHits;

        result.sourceMisses +=
            execution.resolveStats.sourceMisses;

        result.storeInsertions +=
            execution.resolveStats.storeInsertions;

        result.storeInsertionRejections +=
            execution.resolveStats.storeInsertionRejections;

        const relativeTaskX =
            task.x
            - requestedOutput.x;

        const relativeTaskY =
            task.y
            - requestedOutput.y;

        size_t taskIndex;

        foreach (y; 0 .. task.height)
        {
            foreach (x; 0 .. task.width)
            {
                result.output[
                    (
                        relativeTaskY + y
                    )
                    * requestedOutput.width
                    + relativeTaskX
                    + x
                ] =
                    execution.output[
                        taskIndex++
                    ];
            }
        }

        assert(taskIndex == execution.output.length);
        assert(budget.admittedBytes == 0);
    }

    result.sourceCalls =
        source.calls;

    result.retainedStoreBytes =
        store.retainedBytes;

    result.ok = true;

    return result;
}


private
Region2D[]
horizontalTasks(
    Region2D request,
    size_t nominalHeight
)
@safe
{
    Region2D[] result;

    size_t y =
        request.y;

    const bottom =
        request.y
        + request.height;

    while (y < bottom)
    {
        const height =
            y + nominalHeight <= bottom
            ? nominalHeight
            : bottom - y;

        result ~=
            Region2D(
                request.x,
                y,
                request.width,
                height
            );

        y +=
            height;
    }

    return result;
}


private
Region2D[]
verticalTasks(
    Region2D request,
    size_t nominalWidth
)
@safe
{
    Region2D[] result;

    size_t x =
        request.x;

    const right =
        request.x
        + request.width;

    while (x < right)
    {
        const width =
            x + nominalWidth <= right
            ? nominalWidth
            : right - x;

        result ~=
            Region2D(
                x,
                request.y,
                width,
                request.height
            );

        x +=
            width;
    }

    return result;
}


private
Region2D[]
regularTasks(
    Region2D request,
    size_t nominalWidth,
    size_t nominalHeight
)
@safe
{
    Region2D[] result;

    const right =
        request.x
        + request.width;

    const bottom =
        request.y
        + request.height;

    size_t y =
        request.y;

    while (y < bottom)
    {
        const height =
            y + nominalHeight <= bottom
            ? nominalHeight
            : bottom - y;

        size_t x =
            request.x;

        while (x < right)
        {
            const width =
                x + nominalWidth <= right
                ? nominalWidth
                : right - x;

            result ~=
                Region2D(
                    x,
                    y,
                    width,
                    height
                );

            x +=
                width;
        }

        y +=
            height;
    }

    return result;
}


private
Region2D[]
irregularTasks(
    Region2D request
)
@safe
{
    assert(request.width == 73);
    assert(request.height == 55);

    Region2D[] result;

    immutable size_t[4] topX =
        [0, 20, 50, 73];

    immutable size_t[5] midX =
        [0, 15, 43, 60, 73];

    immutable size_t[4] bottomX =
        [0, 27, 52, 73];

    foreach (i; 0 .. topX.length - 1)
    {
        result ~=
            Region2D(
                request.x + topX[i],
                request.y,
                topX[i + 1] - topX[i],
                17
            );
    }

    foreach (i; 0 .. midX.length - 1)
    {
        result ~=
            Region2D(
                request.x + midX[i],
                request.y + 17,
                midX[i + 1] - midX[i],
                19
            );
    }

    foreach (i; 0 .. bottomX.length - 1)
    {
        result ~=
            Region2D(
                request.x + bottomX[i],
                request.y + 36,
                bottomX[i + 1] - bottomX[i],
                19
            );
    }

    return result;
}


private
Region2D[]
pixelTasks(
    Region2D request
)
@safe
{
    Region2D[] result;

    foreach (y; 0 .. request.height)
    {
        foreach (x; 0 .. request.width)
        {
            result ~=
                Region2D(
                    request.x + x,
                    request.y + y,
                    1,
                    1
                );
        }
    }

    return result;
}


private
void assertSame(
    scope const(ubyte)[] lhs,
    scope const(ubyte)[] rhs
)
@safe
{
    assert(lhs.length == rhs.length);

    foreach (index; 0 .. lhs.length)
    {
        assert(lhs[index] == rhs[index]);
    }
}


unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            300,
            240
        );

    const requestedOutput =
        Region2D(
            1061,
            2057,
            73,
            55
        );

    Region2D[1] wholeTasks =
    [
        requestedOutput
    ];

    auto whole =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            wholeTasks[]
        );

    assert(whole.ok);
    assert(whole.sourceMisses > 0);
    assert(whole.retainedHits == 0);

    auto horizontal =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            horizontalTasks(
                requestedOutput,
                11
            )
        );

    auto vertical =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            verticalTasks(
                requestedOutput,
                13
            )
        );

    auto regular =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            regularTasks(
                requestedOutput,
                17,
                13
            )
        );

    auto irregular =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            irregularTasks(
                requestedOutput
            )
        );

    assert(horizontal.ok);
    assert(vertical.ok);
    assert(regular.ok);
    assert(irregular.ok);

    assertSame(
        whole.output,
        horizontal.output
    );

    assertSame(
        whole.output,
        vertical.output
    );

    assertSame(
        whole.output,
        regular.output
    );

    assertSame(
        whole.output,
        irregular.output
    );

    assert(horizontal.retainedHits > 0);
    assert(vertical.retainedHits > 0);
    assert(regular.retainedHits > 0);
    assert(irregular.retainedHits > 0);

    assert(regular.sourceMisses > 0);
    assert(regular.sourceCalls == regular.sourceMisses);

    assert(
        regular.peakAdmittedBytes
        < whole.peakAdmittedBytes
    );

    assert(regular.retainedStoreBytes > 0);
    assert(regular.peakAdmittedBytes > 0);

    /*
     * Cache-block geometry and notional provider geometry are deliberately
     * different from regular task geometry.
     */
    assert(cacheBlockWidth == 16);
    assert(cacheBlockHeight == 12);
    assert(cacheBlockWidth != 17);
    assert(cacheBlockHeight != 13);

    ProceduralSource geometryProbe =
        ProceduralSource(
            logicalExtent
        );

    assert(geometryProbe.providerBlockWidth == 13);
    assert(geometryProbe.providerBlockHeight == 7);
    assert(geometryProbe.providerBlockWidth != cacheBlockWidth);
    assert(geometryProbe.providerBlockHeight != cacheBlockHeight);

    /*
     * Explicit seam-neighbour checks around one regular task boundary.
     */
    enum size_t seamX = 17;
    enum size_t seamY = 13;

    foreach (
        coordinate;
        [
            (seamY - 1) * requestedOutput.width + seamX - 1,
            (seamY - 1) * requestedOutput.width + seamX,
            seamY * requestedOutput.width + seamX - 1,
            seamY * requestedOutput.width + seamX
        ]
    )
    {
        assert(
            regular.output[coordinate]
            == whole.output[coordinate]
        );
    }
}


unittest
{
    const logicalExtent =
        Region2D(
            500,
            700,
            50,
            40
        );

    const requestedOutput =
        Region2D(
            510,
            710,
            5,
            4
        );

    Region2D[1] wholeTasks =
    [
        requestedOutput
    ];

    auto whole =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            wholeTasks[]
        );

    auto streamed =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            pixelTasks(
                requestedOutput
            )
        );

    assert(whole.ok);
    assert(streamed.ok);

    assertSame(
        whole.output,
        streamed.output
    );

    assert(streamed.retainedHits > 0);
    assert(
        streamed.peakAdmittedBytes
        < whole.peakAdmittedBytes
    );
}


unittest
{
    const logicalExtent =
        Region2D(
            size_t.max - 1000,
            size_t.max - 2000,
            400,
            500
        );

    const requestedOutput =
        Region2D(
            size_t.max - 900,
            size_t.max - 1800,
            7,
            5
        );

    Region2D[1] wholeTasks =
    [
        requestedOutput
    ];

    auto whole =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            wholeTasks[]
        );

    auto streamed =
        executeDecomposition(
            logicalExtent,
            requestedOutput,
            horizontalTasks(
                requestedOutput,
                2
            )
        );

    assert(whole.ok);
    assert(streamed.ok);

    assertSame(
        whole.output,
        streamed.output
    );
}


unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            20
        );

    const edgeOutput =
        Region2D(
            100,
            205,
            5,
            4
        );

    RequestMaterializationPlan plan;

    assert(
        tryPlanRequestMaterialization(
            logicalExtent,
            edgeOutput,
            DependencyMargins(
                1,
                1,
                1,
                1
            ),
            plan
        )
    );

    assert(
        plan.dependency.contextDeficit.left
        == 1
    );

    assert(
        plan.dependency.contextDeficit
        != ContextDeficit.init
    );
}


unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            20
        );

    const emptyOutput =
        Region2D(
            110,
            210,
            0,
            0
        );

    RequestMaterializationPlan plan;

    assert(
        tryPlanRequestMaterialization(
            logicalExtent,
            emptyOutput,
            DependencyMargins(
                1,
                1,
                1,
                1
            ),
            plan
        )
    );

    assert(plan.dependency.validInput.empty());
    assert(plan.residentInput.empty());
    assert(plan.residentOutput.empty());
    assert(
        plan.dependency.contextDeficit
        == ContextDeficit.init
    );
}

} // version (unittest)
