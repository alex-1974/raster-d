module identity_streaming;

import core.stdc.stdlib :
    free,
    malloc;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import imagery.raster :
    OwnedByteResource,
    OwnedRasterImportError,
    PlaneByteLayout,
    RasterCopyError,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryCopyRasterPlane,
    tryImportOwnedRaster;

import procedural_source :
    ProceduralMaterializationError,
    materializeProcedural,
    proceduralValue;

import std.algorithm.mutation :
    move;


/++
    E3.2.2 identity-execution failure category.

    This remains research diagnostics rather than a proposed production error
    hierarchy.
+/
enum IdentityExecutionError : ubyte
{
    none,

    invalidRequest,
    invalidDecomposition,

    dependencyDerivationFailed,
    dependencyContractMismatch,

    sourceMaterializationFailed,

    destinationLayoutNotRepresentable,
    destinationAllocationFailed,
    destinationAdoptionFailed,
    destinationImportFailed,
    destinationWritableBorrowFailed,
    destinationInitializationFailed,

    rasterCopyFailed,
    sampleReadFailed,

    internalFailure
}


/++
    Raster-residency and oracle accounting for one identity execution.

    Oracle memory is intentionally reported separately from resident raster
    storage.
+/
struct IdentityExecutionAccounting
{
    size_t requestedOutputBytes;

    size_t sourceResidentBytes;
    size_t destinationResidentBytes;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;

    size_t sourceMaterializations;
    size_t totalMaterializedSourcePixels;

    size_t oracleBytes;
}


/++
    Result of one E3.2.2 identity execution.
+/
struct IdentityExecutionResult
{
    IdentityExecutionError error =
        IdentityExecutionError.internalFailure;

    ProceduralMaterializationError sourceError =
        ProceduralMaterializationError.none;

    OwnedRasterImportError destinationImportError =
        OwnedRasterImportError.none;

    RasterCopyError copyError =
        RasterCopyError.none;

    DecompositionIssue decompositionIssue =
        DecompositionIssue.none;

    IdentityExecutionAccounting accounting;

    ubyte[] output;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == IdentityExecutionError.none;
    }
}


/++
    Internal result for one blank writable resident destination.
+/
private
struct BlankResidentResult
{
    IdentityExecutionError error =
        IdentityExecutionError.internalFailure;

    OwnedRasterImportError importError =
        OwnedRasterImportError.none;

    RasterLease!ubyte lease;

    size_t residentBytes;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == IdentityExecutionError.none;
    }
}


/++
    Allocates one blank retained single-plane ubyte raster.

    The caller supplies resident dimensions only. The resulting raster always
    begins at resident descriptor-space origin `(0, 0)`.

    Raw malloc ownership crosses only this narrow trusted boundary.
+/
private
BlankResidentResult allocateBlankResident(
    size_t width,
    size_t height
)
@trusted
{
    BlankResidentResult result;

    if (
        width == 0
        || height == 0
    )
    {
        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    if (
        width != 0
        && height > size_t.max / width
    )
    {
        result.error =
            IdentityExecutionError
                .destinationLayoutNotRepresentable;

        return result;
    }

    const sampleCount =
        width * height;

    if (
        width > cast(size_t) ptrdiff_t.max
        || sampleCount - 1
            > cast(size_t) ptrdiff_t.max
    )
    {
        result.error =
            IdentityExecutionError
                .destinationLayoutNotRepresentable;

        return result;
    }

    void* memory =
        malloc(sampleCount);

    if (memory is null)
    {
        result.error =
            IdentityExecutionError
                .destinationAllocationFailed;

        return result;
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(
        memory,
        sampleCount,
        resource
    ))
    {
        /*
         * Adoption failed, so ownership never transferred to resource.
         */
        free(memory);

        result.error =
            IdentityExecutionError
                .destinationAdoptionFailed;

        return result;
    }

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t) width,
            1
        )
    ];

    RasterLease!ubyte lease;

    const importResult =
        tryImportOwnedRaster!ubyte(
            resource,
            layouts[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    if (!importResult.ok)
    {
        /*
         * Failed import leaves the resource owned by the local token.
         */
        result.error =
            IdentityExecutionError
                .destinationImportFailed;

        result.importError =
            importResult.error;

        return result;
    }

    assert(!resource.ownsResource);

    result.error =
        IdentityExecutionError.none;

    result.residentBytes =
        sampleCount;

    result.lease =
        move(lease);

    return result;
}


/++
    Executes identity once for one complete logical output request.

    E3.2.2a deliberately uses one member equal to the entire requested output.
    Later E3.2.2 stages reuse the same execution path for streamed
    decompositions.

    Processing path:

        validate whole-request decomposition
            ->
        derive zero-margin dependency
            ->
        materialize procedural source
            ->
        allocate distinct writable destination
            ->
        initialize destination with sentinel data
            ->
        tryCopyRasterPlane()
            ->
        inspect result through RasterView.trySample()
            ->
        return ordinary oracle buffer

    The logical request origin never becomes resident RasterView geometry.
+/
IdentityExecutionResult executeWholeIdentity(
    Region2D logicalExtent,
    Region2D requestedOutput
)
@safe
{
    IdentityExecutionResult result;

    /*
     * Whatever path leaves this function, no task raster remains logically
     * resident after the call has completed.
     */
    scope(exit)
    {
        result.accounting.currentResidentRasterBytes = 0;
    }

    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    const Region2D[1] wholeDecomposition =
    [
        requestedOutput
    ];

    DecompositionIssue decompositionIssue;

    if (!tryValidateDecomposition(
        requestedOutput,
        wholeDecomposition[],
        decompositionIssue
    ))
    {
        result.error =
            IdentityExecutionError.invalidDecomposition;

        result.decompositionIssue =
            decompositionIssue;

        return result;
    }

    assert(
        decompositionIssue
        == DecompositionIssue.none
    );

    result.decompositionIssue =
        decompositionIssue;


    ExpandedDependency dependency;

    if (!tryExpandDependency(
        logicalExtent,
        requestedOutput,
        DependencyMargins.init,
        dependency
    ))
    {
        result.error =
            IdentityExecutionError
                .dependencyDerivationFailed;

        return result;
    }

    if (
        dependency.validInput
            != requestedOutput
        || dependency.contextDeficit
            != ContextDeficit.init
    )
    {
        result.error =
            IdentityExecutionError
                .dependencyContractMismatch;

        return result;
    }


    auto source =
        materializeProcedural(
            logicalExtent,
            dependency.validInput
        );

    if (!source.ok)
    {
        result.error =
            IdentityExecutionError
                .sourceMaterializationFailed;

        result.sourceError =
            source.error;

        return result;
    }

    assert(
        source.materialized.logicalRequest
        == requestedOutput
    );

    auto sourceView =
        source.materialized.lease.view();

    assert(
        sourceView.region
        == Region2D(
            0,
            0,
            requestedOutput.width,
            requestedOutput.height
        )
    );


    auto destination =
        allocateBlankResident(
            requestedOutput.width,
            requestedOutput.height
        );

    if (!destination.ok)
    {
        result.error =
            destination.error;

        result.destinationImportError =
            destination.importError;

        return result;
    }

    auto destinationView =
        destination.lease.view();

    assert(
        destinationView.region
        == sourceView.region
    );


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    assert(
        sampleCount
        == source.materialized.residentBytes
    );

    assert(
        sampleCount
        == destination.residentBytes
    );


    result.accounting.requestedOutputBytes =
        sampleCount;

    result.accounting.sourceResidentBytes =
        source.materialized.residentBytes;

    result.accounting.destinationResidentBytes =
        destination.residentBytes;

    result.accounting.sourceMaterializations = 1;

    result.accounting.totalMaterializedSourcePixels =
        sampleCount;

    result.accounting.oracleBytes =
        sampleCount;


    result.accounting.currentResidentRasterBytes =
        result.accounting.sourceResidentBytes;

    result.accounting.peakResidentRasterBytes =
        result.accounting.currentResidentRasterBytes;

    result.accounting.currentResidentRasterBytes +=
        result.accounting.destinationResidentBytes;

    if (
        result.accounting.currentResidentRasterBytes
        > result.accounting.peakResidentRasterBytes
    )
    {
        result.accounting.peakResidentRasterBytes =
            result.accounting.currentResidentRasterBytes;
    }


    {
        bool writableSuccess;

        scope auto writable =
            destination.lease.tryWritableView(
                writableSuccess
            );

        if (!writableSuccess)
        {
            result.error =
                IdentityExecutionError
                    .destinationWritableBorrowFailed;

            return result;
        }

        /*
         * Sentinel initialization prevents an accidentally skipped copy from
         * inheriting a correct procedural result by construction.
         *
         * This loop is test setup, not the identity operation under test.
         */
        enum ubyte sentinel = 0xA5;

        foreach (y; 0 .. requestedOutput.height)
        {
            foreach (x; 0 .. requestedOutput.width)
            {
                if (!writable.trySetSample(
                    0,
                    x,
                    y,
                    sentinel
                ))
                {
                    result.error =
                        IdentityExecutionError
                            .destinationInitializationFailed;

                    return result;
                }
            }
        }


        RasterCopyError copyError;

        if (!tryCopyRasterPlane(
            sourceView,
            0,
            writable,
            0,
            copyError
        ))
        {
            result.error =
                IdentityExecutionError
                    .rasterCopyFailed;

            result.copyError =
                copyError;

            return result;
        }

        assert(
            copyError
            == RasterCopyError.none
        );

        result.copyError =
            copyError;
    }


    /*
     * The writable borrow has ended before the ordinary read-only result view
     * is obtained.
     */
    destinationView =
        destination.lease.view();

    result.output =
        new ubyte[sampleCount];

    foreach (y; 0 .. requestedOutput.height)
    {
        foreach (x; 0 .. requestedOutput.width)
        {
            ubyte value;

            if (!destinationView.trySample(
                0,
                x,
                y,
                value
            ))
            {
                result.error =
                    IdentityExecutionError
                        .sampleReadFailed;

                return result;
            }

            const index =
                y * requestedOutput.width
                + x;

            result.output[index] =
                value;
        }
    }


    result.error =
        IdentityExecutionError.none;

    return result;
}


/*
 * E3.2.2a whole-request identity execution.
 *
 * This uses the principal non-zero-origin fixture from the E3.2 contract.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            8192,
            6144
        );

    const requestedOutput =
        Region2D(
            1733,
            911,
            1021,
            769
        );

    auto result =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(result.ok);

    assert(
        result.error
        == IdentityExecutionError.none
    );

    assert(
        result.decompositionIssue
        == DecompositionIssue.none
    );

    assert(
        result.sourceError
        == ProceduralMaterializationError.none
    );

    assert(
        result.destinationImportError
        == OwnedRasterImportError.none
    );

    assert(
        result.copyError
        == RasterCopyError.none
    );


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    assert(
        result.output.length
        == sampleCount
    );

    foreach (localY; 0 .. requestedOutput.height)
    {
        foreach (localX; 0 .. requestedOutput.width)
        {
            const index =
                localY * requestedOutput.width
                + localX;

            assert(
                result.output[index]
                ==
                proceduralValue(
                    requestedOutput.x + localX,
                    requestedOutput.y + localY
                )
            );
        }
    }


    assert(
        result.accounting.requestedOutputBytes
        == sampleCount
    );

    assert(
        result.accounting.sourceResidentBytes
        == sampleCount
    );

    assert(
        result.accounting.destinationResidentBytes
        == sampleCount
    );

    assert(
        result.accounting.sourceMaterializations
        == 1
    );

    assert(
        result.accounting.totalMaterializedSourcePixels
        == sampleCount
    );

    assert(
        result.accounting.oracleBytes
        == sampleCount
    );

    assert(
        result.accounting.peakResidentRasterBytes
        == sampleCount * 2
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );
}


/*
 * Empty output remains outside the resident execution path.
 */
unittest
{
    const result =
        executeWholeIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 0, 5)
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        result.accounting.peakResidentRasterBytes
        == 0
    );
}



/++
    Executes identity for one already-defined decomposition of a requested
    output.

    The complete decomposition is validated before any resident raster is
    materialized.

    Tasks are then processed sequentially through the already proven
    whole-request task path.

    `sourceResidentBytes` and `destinationResidentBytes` report the largest
    corresponding single-task materialization for a decomposed execution.

    `peakResidentRasterBytes` reports the largest simultaneously resident
    source-plus-destination task pair.

    `oracleBytes` reports the returned reassembled output buffer only. It is
    deliberately separate from resident raster accounting.
+/
IdentityExecutionResult executeIdentityDecomposition(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
@safe
{
    IdentityExecutionResult result;

    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }


    DecompositionIssue decompositionIssue;

    if (!tryValidateDecomposition(
        requestedOutput,
        tasks,
        decompositionIssue
    ))
    {
        result.error =
            IdentityExecutionError.invalidDecomposition;

        result.decompositionIssue =
            decompositionIssue;

        return result;
    }

    assert(
        decompositionIssue
        == DecompositionIssue.none
    );

    result.decompositionIssue =
        decompositionIssue;


    /*
     * Successful bounded decomposition validation already checked this
     * multiplication before constructing its coverage oracle.
     */
    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.accounting.requestedOutputBytes =
        sampleCount;

    result.accounting.oracleBytes =
        sampleCount;


    foreach (const task; tasks)
    {
        if (task.empty())
        {
            /*
             * The decomposition oracle permits empty members because they
             * contribute no coverage. They require no resident execution.
             */
            continue;
        }

        auto taskResult =
            executeWholeIdentity(
                logicalExtent,
                task
            );

        if (!taskResult.ok)
        {
            result.error =
                taskResult.error;

            result.sourceError =
                taskResult.sourceError;

            result.destinationImportError =
                taskResult.destinationImportError;

            result.copyError =
                taskResult.copyError;

            /*
             * The complete decomposition itself was already valid. Preserve
             * that diagnostic instead of replacing it with the task-local
             * one-member validation result.
             */
            return result;
        }

        assert(
            taskResult.accounting
                .currentResidentRasterBytes
            == 0
        );


        if (
            taskResult.accounting.sourceResidentBytes
            > result.accounting.sourceResidentBytes
        )
        {
            result.accounting.sourceResidentBytes =
                taskResult.accounting.sourceResidentBytes;
        }

        if (
            taskResult.accounting.destinationResidentBytes
            > result.accounting.destinationResidentBytes
        )
        {
            result.accounting.destinationResidentBytes =
                taskResult.accounting.destinationResidentBytes;
        }

        if (
            taskResult.accounting.peakResidentRasterBytes
            > result.accounting.peakResidentRasterBytes
        )
        {
            result.accounting.peakResidentRasterBytes =
                taskResult.accounting.peakResidentRasterBytes;
        }


        result.accounting.sourceMaterializations +=
            taskResult.accounting.sourceMaterializations;

        result.accounting.totalMaterializedSourcePixels +=
            taskResult.accounting.totalMaterializedSourcePixels;


        /*
         * Exact decomposition containment proves both subtractions safe.
         */
        const relativeX =
            task.x - requestedOutput.x;

        const relativeY =
            task.y - requestedOutput.y;


        assert(
            taskResult.output.length
            == task.width * task.height
        );

        foreach (localY; 0 .. task.height)
        {
            foreach (localX; 0 .. task.width)
            {
                const taskIndex =
                    localY * task.width
                    + localX;

                const outputIndex =
                    (relativeY + localY)
                        * requestedOutput.width
                    + relativeX
                    + localX;

                assert(
                    outputIndex
                    < result.output.length
                );

                result.output[outputIndex] =
                    taskResult.output[taskIndex];
            }
        }
    }


    /*
     * Every task-local resident source/destination pair was destroyed before
     * the next task was entered.
     */
    result.accounting.currentResidentRasterBytes = 0;

    result.error =
        IdentityExecutionError.none;

    return result;
}


/++
    Constructs a horizontal-strip decomposition.

    Every strip spans the complete requested width. The final strip may be
    shorter than `nominalStripHeight`.

    Invalid or empty input, or a zero nominal strip height, produces no tasks.
+/
private
Region2D[] makeHorizontalStrips(
    Region2D requestedOutput,
    size_t nominalStripHeight
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalStripHeight == 0
    )
    {
        return null;
    }

    const completeStripCount =
        requestedOutput.height
        / nominalStripHeight;

    const remainder =
        requestedOutput.height
        % nominalStripHeight;

    const stripCount =
        completeStripCount
        + (remainder == 0 ? 0 : 1);

    assert(stripCount != 0);

    auto tasks =
        new Region2D[stripCount];

    size_t currentY =
        requestedOutput.y;

    size_t remainingHeight =
        requestedOutput.height;

    foreach (ref task; tasks)
    {
        const height =
            remainingHeight < nominalStripHeight
            ? remainingHeight
            : nominalStripHeight;

        assert(height != 0);

        task =
            Region2D(
                requestedOutput.x,
                currentY,
                requestedOutput.width,
                height
            );

        /*
         * requestedOutput representability proves this addition safe.
         */
        currentY +=
            height;

        remainingHeight -=
            height;
    }

    assert(remainingHeight == 0);

    assert(
        currentY
        == requestedOutput.y
            + requestedOutput.height
    );

    return tasks;
}


/++
    Executes identity as sequential horizontal strips.
+/
IdentityExecutionResult executeHorizontalStripIdentity(
    Region2D logicalExtent,
    Region2D requestedOutput,
    size_t nominalStripHeight
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalStripHeight == 0
    )
    {
        IdentityExecutionResult result;

        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    const tasks =
        makeHorizontalStrips(
            requestedOutput,
            nominalStripHeight
        );

    assert(tasks.length != 0);

    return executeIdentityDecomposition(
        logicalExtent,
        requestedOutput,
        tasks
    );
}


/*
 * E3.2.3 horizontal-strip streamed equivalence.
 *
 * The principal fixture height is 769. A nominal strip height of 128 creates:
 *
 *     6 * 128 + 1
 *
 * so the final strip is deliberately smaller than the nominal task height.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            8192,
            6144
        );

    const requestedOutput =
        Region2D(
            1733,
            911,
            1021,
            769
        );

    enum size_t nominalStripHeight =
        128;


    const tasks =
        makeHorizontalStrips(
            requestedOutput,
            nominalStripHeight
        );

    assert(tasks.length == 7);

    foreach (const task; tasks)
    {
        assert(
            task.width
            == requestedOutput.width
        );

        assert(
            task.height
            <= nominalStripHeight
        );
    }

    assert(
        tasks[$ - 1].height
        == 1
    );


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks,
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto streamed =
        executeHorizontalStripIdentity(
            logicalExtent,
            requestedOutput,
            nominalStripHeight
        );

    assert(streamed.ok);

    assert(
        streamed.error
        == IdentityExecutionError.none
    );

    assert(
        streamed.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        streamed.output.length
        == reference.output.length
    );

    /*
     * Identity on ubyte pixels is exact. No tolerance is permitted.
     *
     * Keep the coordinate-aware loop rather than relying only on array
     * equality so any future assertion failure can be localized directly.
     */
    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                streamed.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    const requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    const largestTaskPixels =
        requestedOutput.width
        * nominalStripHeight;


    assert(
        streamed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.oracleBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );


    /*
     * This is the first actual streamed-residency result:
     *
     * the complete requested output remains much larger than one resident
     * strip, while raster residency is bounded by the current task pair.
     */
    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        requestedPixels
    );
}


/*
 * A zero strip height cannot define a streaming decomposition.
 */
unittest
{
    const result =
        executeHorizontalStripIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 10, 10),
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );
}



/++
    Constructs a vertical-strip decomposition.

    Every strip spans the complete requested height. The final strip may be
    narrower than `nominalStripWidth`.

    Invalid or empty input, or a zero nominal strip width, produces no tasks.
+/
private
Region2D[] makeVerticalStrips(
    Region2D requestedOutput,
    size_t nominalStripWidth
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalStripWidth == 0
    )
    {
        return null;
    }

    const completeStripCount =
        requestedOutput.width
        / nominalStripWidth;

    const remainder =
        requestedOutput.width
        % nominalStripWidth;

    const stripCount =
        completeStripCount
        + (remainder == 0 ? 0 : 1);

    assert(stripCount != 0);

    auto tasks =
        new Region2D[stripCount];

    size_t currentX =
        requestedOutput.x;

    size_t remainingWidth =
        requestedOutput.width;

    foreach (ref task; tasks)
    {
        const width =
            remainingWidth < nominalStripWidth
            ? remainingWidth
            : nominalStripWidth;

        assert(width != 0);

        task =
            Region2D(
                currentX,
                requestedOutput.y,
                width,
                requestedOutput.height
            );

        /*
         * requestedOutput representability proves this addition safe.
         */
        currentX +=
            width;

        remainingWidth -=
            width;
    }

    assert(remainingWidth == 0);

    assert(
        currentX
        == requestedOutput.x
            + requestedOutput.width
    );

    return tasks;
}


/++
    Executes identity as sequential vertical strips.
+/
IdentityExecutionResult executeVerticalStripIdentity(
    Region2D logicalExtent,
    Region2D requestedOutput,
    size_t nominalStripWidth
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalStripWidth == 0
    )
    {
        IdentityExecutionResult result;

        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    const tasks =
        makeVerticalStrips(
            requestedOutput,
            nominalStripWidth
        );

    assert(tasks.length != 0);

    return executeIdentityDecomposition(
        logicalExtent,
        requestedOutput,
        tasks
    );
}


/*
 * E3.2.4 vertical-strip streamed equivalence.
 *
 * The principal fixture width is 1021. A nominal strip width of 128 creates:
 *
 *     7 * 128 + 125
 *
 * so the final strip is deliberately narrower than the nominal task width.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            8192,
            6144
        );

    const requestedOutput =
        Region2D(
            1733,
            911,
            1021,
            769
        );

    enum size_t nominalStripWidth =
        128;


    const tasks =
        makeVerticalStrips(
            requestedOutput,
            nominalStripWidth
        );

    assert(tasks.length == 8);

    foreach (const task; tasks)
    {
        assert(
            task.height
            == requestedOutput.height
        );

        assert(
            task.width
            <= nominalStripWidth
        );
    }

    assert(
        tasks[$ - 1].width
        == 125
    );


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks,
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto streamed =
        executeVerticalStripIdentity(
            logicalExtent,
            requestedOutput,
            nominalStripWidth
        );

    assert(streamed.ok);

    assert(
        streamed.error
        == IdentityExecutionError.none
    );

    assert(
        streamed.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        streamed.output.length
        == reference.output.length
    );

    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                streamed.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    const requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    const largestTaskPixels =
        nominalStripWidth
        * requestedOutput.height;


    assert(
        streamed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.oracleBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );


    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        requestedPixels
    );
}


/*
 * A zero strip width cannot define a streaming decomposition.
 */
unittest
{
    const result =
        executeVerticalStripIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 10, 10),
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );
}
