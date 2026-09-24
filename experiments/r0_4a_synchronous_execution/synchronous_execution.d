module synchronous_execution;

import raster.region :
    Region2D;

import region_algebra :
    tryContainsAbsolute;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import procedural_source :
    MaterializedUbyteRaster,
    materializeProcedural;

import neighbourhood_kernel :
    weightedNeighbourhood3x3;

import neighbourhood_task_execution :
    executeNeighbourhoodTask;


/++
    R0.4a research-only work-unit failure category.

    This is not a proposed production error model.
+/
enum WorkUnitError : ubyte
{
    none,

    invalidTask,

    dependencyDerivationFailed,
    unsatisfiedContext,

    materializationFailed,
    operationFailed,

    sourceContractMismatch,

    sampleCountOverflow,
    sampleReadFailed,

    internalFailure
}


/++
    R0.4a research-only request-execution failure category.
+/
enum SynchronousExecutionError : ubyte
{
    none,

    invalidRequest,
    invalidDecomposition,

    workUnitFailed,
    residencyInvariantFailed,

    internalFailure
}


/++
    High-level request termination state.

    Failure subtype remains available through `error` and `workUnitError`.

    `cancelled` is reserved now so that the later cancellation experiment does
    not need to redefine request-completion semantics.
+/
enum TerminationReason : ubyte
{
    failed,
    completed,
    cancelled
}


/++
    Deterministic research-only failure injection.

    `workUnitOrdinal` is one-based and counts only non-empty work units.

    This is experiment machinery, not a proposed execution API.
+/
private enum FailureInjectionKind : ubyte
{
    none,
    materialization,
    operation
}


private struct FailureInjection
{
    FailureInjectionKind kind;

    size_t workUnitOrdinal;


    @property
    bool active() const
    @safe
    pure
    nothrow
    @nogc
    {
        return kind
            != FailureInjectionKind.none;
    }


    bool matches(
        FailureInjectionKind expectedKind,
        size_t ordinal
    ) const
    @safe
    pure
    nothrow
    @nogc
    {
        return active
            && kind == expectedKind
            && workUnitOrdinal == ordinal;
    }
}



/++
    Deterministic research-only cancellation observation.

    `beforeWorkUnitOrdinal` is one-based and counts only non-empty work units.

    A value of zero disables cancellation.

    Cancellation is observed only by the outer synchronous orchestration before
    a work unit begins. It is never checked inside an executing work unit.

    This is experiment machinery, not a proposed cancellation API.
+/
private struct CancellationInjection
{
    size_t beforeWorkUnitOrdinal;


    @property
    bool active() const
    @safe
    pure
    nothrow
    @nogc
    {
        return beforeWorkUnitOrdinal != 0;
    }


    bool matches(size_t nextWorkUnitOrdinal) const
    @safe
    pure
    nothrow
    @nogc
    {
        return active
            && beforeWorkUnitOrdinal
                == nextWorkUnitOrdinal;
    }
}


/++
    Lifecycle accounting for the synchronous R0.4a path.

    These counters describe only the execution path under test.

    Calls to the independent R0.3 success oracle in unittests are deliberately
    outside this accounting.
+/
struct SynchronousExecutionAccounting
{
    size_t workUnitsConsidered;

    size_t workUnitsStarted;
    size_t workUnitsCompleted;

    size_t materializationsStarted;
    size_t materializationsCompleted;

    size_t operationExecutionsStarted;
    size_t operationExecutionsCompleted;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;

    size_t completedOutputPixels;

    size_t releases;
}


/++
    Result of one R0.4a work unit.

    `output` is ordinary research result storage.

    It is not counted as resident raster materialization.
+/
private struct WorkUnitResult
{
    WorkUnitError error =
        WorkUnitError.internalFailure;

    ubyte[] output;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == WorkUnitError.none;
    }
}


/++
    Result of one complete synchronous request execution.

    `requestCompleted` is distinct from the existence of any completed
    work-unit output.
+/
struct SynchronousExecutionResult
{
    SynchronousExecutionError error =
        SynchronousExecutionError.internalFailure;

    TerminationReason termination =
        TerminationReason.failed;

    DecompositionIssue decompositionIssue =
        DecompositionIssue.none;

    WorkUnitError workUnitError =
        WorkUnitError.none;

    bool requestCompleted;

    ubyte[] output;

    /*
     * Test/research oracle only.
     *
     * One byte per requested output pixel:
     *
     *     0 -> no successfully completed work unit produced this pixel
     *     1 -> a successfully completed work unit produced this pixel
     */
    ubyte[] completedCoverage;

    SynchronousExecutionAccounting accounting;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == SynchronousExecutionError.none
            && requestCompleted;
    }
}


private DependencyMargins neighbourhoodMargins()
@safe
pure
nothrow
@nogc
{
    return DependencyMargins(
        1,
        1,
        1,
        1
    );
}


/++
    Executes the exact R0.3 weighted neighbourhood operation against an already
    materialized source.

    This function owns no raster lifetime.

    The caller retains the materialized raster for the complete call.
+/
private WorkUnitResult executeResidentNeighbourhood(
    Region2D outputTask,
    ExpandedDependency dependency,
    ref MaterializedUbyteRaster source
)
@safe
{
    WorkUnitResult result;


    if (
        source.logicalRequest
        != dependency.validInput
    )
    {
        result.error =
            WorkUnitError.sourceContractMismatch;

        return result;
    }


    auto sourceView =
        source.lease.view();

    const expectedResidentRegion =
        Region2D(
            0,
            0,
            dependency.validInput.width,
            dependency.validInput.height
        );

    if (
        sourceView.region
        != expectedResidentRegion
    )
    {
        result.error =
            WorkUnitError.sourceContractMismatch;

        return result;
    }


    if (
        dependency.validInput.x
            > outputTask.x
        || dependency.validInput.y
            > outputTask.y
    )
    {
        result.error =
            WorkUnitError.sourceContractMismatch;

        return result;
    }


    const sourceBaseX =
        outputTask.x
        - dependency.validInput.x;

    const sourceBaseY =
        outputTask.y
        - dependency.validInput.y;


    if (
        sourceBaseX < 1
        || sourceBaseY < 1
        || sourceBaseX >= sourceView.region.width
        || sourceBaseY >= sourceView.region.height
    )
    {
        result.error =
            WorkUnitError.sourceContractMismatch;

        return result;
    }


    const availableFromBaseX =
        sourceView.region.width
        - sourceBaseX;

    const availableFromBaseY =
        sourceView.region.height
        - sourceBaseY;

    if (
        outputTask.width >= availableFromBaseX
        || outputTask.height >= availableFromBaseY
    )
    {
        result.error =
            WorkUnitError.sourceContractMismatch;

        return result;
    }


    if (
        outputTask.width != 0
        && outputTask.height
            > size_t.max / outputTask.width
    )
    {
        result.error =
            WorkUnitError.sampleCountOverflow;

        return result;
    }


    const sampleCount =
        outputTask.width
        * outputTask.height;

    assert(sampleCount != 0);

    result.output =
        new ubyte[sampleCount];


    foreach (localY; 0 .. outputTask.height)
    {
        const centerY =
            sourceBaseY
            + localY;

        assert(centerY >= 1);
        assert(centerY + 1 < sourceView.region.height);

        foreach (localX; 0 .. outputTask.width)
        {
            const centerX =
                sourceBaseX
                + localX;

            assert(centerX >= 1);
            assert(centerX + 1 < sourceView.region.width);


            ubyte northWest;
            ubyte north;
            ubyte northEast;

            ubyte west;
            ubyte center;
            ubyte east;

            ubyte southWest;
            ubyte south;
            ubyte southEast;


            if (
                !sourceView.trySample(
                    0,
                    centerX - 1,
                    centerY - 1,
                    northWest
                )
                || !sourceView.trySample(
                    0,
                    centerX,
                    centerY - 1,
                    north
                )
                || !sourceView.trySample(
                    0,
                    centerX + 1,
                    centerY - 1,
                    northEast
                )
                || !sourceView.trySample(
                    0,
                    centerX - 1,
                    centerY,
                    west
                )
                || !sourceView.trySample(
                    0,
                    centerX,
                    centerY,
                    center
                )
                || !sourceView.trySample(
                    0,
                    centerX + 1,
                    centerY,
                    east
                )
                || !sourceView.trySample(
                    0,
                    centerX - 1,
                    centerY + 1,
                    southWest
                )
                || !sourceView.trySample(
                    0,
                    centerX,
                    centerY + 1,
                    south
                )
                || !sourceView.trySample(
                    0,
                    centerX + 1,
                    centerY + 1,
                    southEast
                )
            )
            {
                result.error =
                    WorkUnitError.sampleReadFailed;

                return result;
            }


            const outputIndex =
                localY * outputTask.width
                + localX;

            result.output[outputIndex] =
                weightedNeighbourhood3x3(
                    northWest,
                    north,
                    northEast,
                    west,
                    center,
                    east,
                    southWest,
                    south,
                    southEast
                );
        }
    }


    result.error =
        WorkUnitError.none;

    return result;
}


/++
    Executes one non-empty R0.4a work unit.

    The resident source is deliberately scoped inside this function.

    Lifecycle:

        derive dependency
            ->
        materialize
            ->
        account resident bytes
            ->
        execute operation
            ->
        leave materialization scope
            ->
        record release
            ->
        establish work-unit completion

    No scheduler is involved.
+/
private WorkUnitResult executeWorkUnit(
    Region2D logicalExtent,
    Region2D outputTask,
    size_t workUnitOrdinal,
    FailureInjection injection,
    ref SynchronousExecutionAccounting accounting
)
@safe
{
    WorkUnitResult result;


    if (
        !outputTask.hasRepresentableExtent()
        || outputTask.empty()
    )
    {
        result.error =
            WorkUnitError.invalidTask;

        return result;
    }


    ++accounting.workUnitsStarted;


    ExpandedDependency dependency;

    if (!tryExpandDependency(
        logicalExtent,
        outputTask,
        neighbourhoodMargins(),
        dependency
    ))
    {
        result.error =
            WorkUnitError.dependencyDerivationFailed;

        return result;
    }


    if (
        dependency.contextDeficit
        != ContextDeficit.init
    )
    {
        result.error =
            WorkUnitError.unsatisfiedContext;

        return result;
    }


    ++accounting.materializationsStarted;


    if (
        injection.matches(
            FailureInjectionKind.materialization,
            workUnitOrdinal
        )
    )
    {
        result.error =
            WorkUnitError.materializationFailed;

        return result;
    }


    bool acquiredResidentRaster = false;

    {
        auto source =
            materializeProcedural(
                logicalExtent,
                dependency.validInput
            );


        if (!source.ok)
        {
            result.error =
                WorkUnitError.materializationFailed;
        }
        else
        {
            acquiredResidentRaster = true;

            ++accounting.materializationsCompleted;

            accounting.currentResidentRasterBytes =
                source.materialized.residentBytes;

            if (
                accounting.currentResidentRasterBytes
                > accounting.peakResidentRasterBytes
            )
            {
                accounting.peakResidentRasterBytes =
                    accounting.currentResidentRasterBytes;
            }


            ++accounting.operationExecutionsStarted;


            if (
                injection.matches(
                    FailureInjectionKind.operation,
                    workUnitOrdinal
                )
            )
            {
                result.error =
                    WorkUnitError.operationFailed;
            }
            else
            {
                result =
                    executeResidentNeighbourhood(
                        outputTask,
                        dependency,
                        source.materialized
                    );

                if (result.ok)
                {
                    ++accounting.operationExecutionsCompleted;
                }
            }
        }
    }


    /*
     * The source materialization has left lexical scope before residency is
     * reported as released.
     */
    if (acquiredResidentRaster)
    {
        accounting.currentResidentRasterBytes = 0;
        ++accounting.releases;
    }


    if (result.ok)
    {
        ++accounting.workUnitsCompleted;
    }

    return result;
}


/++
    Executes one already-defined legal decomposition synchronously.

    The order of `tasks` is the execution order.

    Geometry membership and execution order are deliberately not represented
    separately in this first research implementation: callers construct
    different ordered slices containing the same decomposition members.
+/
private SynchronousExecutionResult executeSynchronousNeighbourhoodImpl(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks,
    FailureInjection injection,
    CancellationInjection cancellation
)
@safe
{
    SynchronousExecutionResult result;


    bool requestContained;

    if (
        !tryContainsAbsolute(
            logicalExtent,
            requestedOutput,
            requestContained
        )
        || !requestContained
    )
    {
        result.error =
            SynchronousExecutionError.invalidRequest;

        return result;
    }


    /*
     * Empty requested output is a successful zero-work request.
     *
     * No synthetic zero-sized work unit is constructed.
     */
    if (requestedOutput.empty())
    {
        foreach (const task; tasks)
        {
            if (
                !task.hasRepresentableExtent()
                || !task.empty()
            )
            {
                result.error =
                    SynchronousExecutionError.invalidDecomposition;

                return result;
            }
        }

        result.requestCompleted = true;

        result.termination =
            TerminationReason.completed;

        result.error =
            SynchronousExecutionError.none;

        return result;
    }


    if (!tryValidateDecomposition(
        requestedOutput,
        tasks,
        result.decompositionIssue
    ))
    {
        result.error =
            SynchronousExecutionError.invalidDecomposition;

        return result;
    }


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.completedCoverage =
        new ubyte[sampleCount];


    foreach (const task; tasks)
    {
        if (task.empty())
        {
            continue;
        }


        /*
         * Cancellation is deliberately observed only between work units.
         *
         * The previous work unit, if any, has already completed, exposed its
         * research result and released its local raster residency.
         *
         * The next work unit has not yet been considered or started.
         */
        const nextWorkUnitOrdinal =
            result.accounting.workUnitsConsidered + 1;

        if (
            cancellation.matches(
                nextWorkUnitOrdinal
            )
        )
        {
            if (
                result.accounting.currentResidentRasterBytes
                != 0
            )
            {
                result.error =
                    SynchronousExecutionError
                        .residencyInvariantFailed;

                return result;
            }

            result.termination =
                TerminationReason.cancelled;

            /*
             * Cancellation is a distinct request termination state rather
             * than an execution failure.
             *
             * `ok` remains false because requestCompleted is false.
             */
            result.error =
                SynchronousExecutionError.none;

            return result;
        }


        ++result.accounting.workUnitsConsidered;

        const workUnitOrdinal =
            result.accounting.workUnitsConsidered;


        auto work =
            executeWorkUnit(
                logicalExtent,
                task,
                workUnitOrdinal,
                injection,
                result.accounting
            );


        if (
            result.accounting.currentResidentRasterBytes
            != 0
        )
        {
            result.error =
                SynchronousExecutionError.residencyInvariantFailed;

            return result;
        }


        if (!work.ok)
        {
            result.error =
                SynchronousExecutionError.workUnitFailed;

            result.workUnitError =
                work.error;

            return result;
        }


        const taskPixels =
            task.width
            * task.height;

        if (
            work.output.length
            != taskPixels
        )
        {
            result.error =
                SynchronousExecutionError.internalFailure;

            return result;
        }


        const relativeX =
            task.x
            - requestedOutput.x;

        const relativeY =
            task.y
            - requestedOutput.y;


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
                    work.output[taskIndex];

                assert(
                    result.completedCoverage[outputIndex]
                    == 0
                );

                result.completedCoverage[outputIndex] = 1;

                ++result.accounting.completedOutputPixels;
            }
        }
    }


    if (
        result.accounting.workUnitsStarted
            != result.accounting.workUnitsCompleted
        || result.accounting.materializationsStarted
            != result.accounting.materializationsCompleted
        || result.accounting.operationExecutionsStarted
            != result.accounting.operationExecutionsCompleted
        || result.accounting.releases
            != result.accounting.materializationsCompleted
        || result.accounting.completedOutputPixels
            != sampleCount
        || result.accounting.currentResidentRasterBytes
            != 0
    )
    {
        result.error =
            SynchronousExecutionError.internalFailure;

        return result;
    }


    result.requestCompleted = true;

    result.termination =
        TerminationReason.completed;

    result.error =
        SynchronousExecutionError.none;

    return result;
}


/++
    Executes the normal R0.4a synchronous path with no injected failure.
+/
SynchronousExecutionResult executeSynchronousNeighbourhood(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
@safe
{
    return executeSynchronousNeighbourhoodImpl(
        logicalExtent,
        requestedOutput,
        tasks,
        FailureInjection.init,
        CancellationInjection.init
    );
}


/*
 * Independent E3.3 success oracle.
 *
 * This helper is used only after the R0.4a lifecycle has completed.
 *
 * Its hidden R0.3 materialization therefore does not participate in the
 * R0.4a lifecycle accounting above.
 */
private bool taskOutputMatchesR03Oracle(
    Region2D logicalExtent,
    Region2D requestedOutput,
    Region2D task,
    scope const(ubyte)[] completeOutput
)
@safe
{
    auto oracle =
        executeNeighbourhoodTask(
            logicalExtent,
            task
        );

    if (!oracle.ok)
    {
        return false;
    }


    if (
        task.width != 0
        && task.height
            > size_t.max / task.width
    )
    {
        return false;
    }


    if (
        oracle.output.length
        != task.width * task.height
    )
    {
        return false;
    }


    const relativeX =
        task.x
        - requestedOutput.x;

    const relativeY =
        task.y
        - requestedOutput.y;


    foreach (localY; 0 .. task.height)
    {
        foreach (localX; 0 .. task.width)
        {
            const oracleIndex =
                localY * task.width
                + localX;

            const completeIndex =
                (relativeY + localY)
                    * requestedOutput.width
                + relativeX
                + localX;

            if (
                completeIndex >= completeOutput.length
                || completeOutput[completeIndex]
                    != oracle.output[oracleIndex]
            )
            {
                return false;
            }
        }
    }

    return true;
}


/*
 * R0.4a success-path evidence.
 *
 * One irregular decomposition is executed:
 *
 * - forward;
 * - reverse;
 * - in one deterministic permutation.
 *
 * The same requested output is also executed as one whole work unit.
 */
unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            100,
            100
        );

    const requestedOutput =
        Region2D(
            1020,
            2030,
            8,
            6
        );


    const Region2D[6] forward =
    [
        Region2D(1020, 2030, 8, 1),

        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),

        Region2D(1020, 2033, 5, 2),
        Region2D(1025, 2033, 3, 2),

        Region2D(1020, 2035, 8, 1)
    ];


    const Region2D[6] reverse =
    [
        forward[5],
        forward[4],
        forward[3],
        forward[2],
        forward[1],
        forward[0]
    ];


    const Region2D[6] permuted =
    [
        forward[2],
        forward[5],
        forward[1],
        forward[4],
        forward[0],
        forward[3]
    ];


    const Region2D[1] whole =
    [
        requestedOutput
    ];


    auto wholeResult =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            whole[]
        );

    auto forwardResult =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            forward[]
        );

    auto reverseResult =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            reverse[]
        );

    auto permutedResult =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            permuted[]
        );


    assert(wholeResult.ok);
    assert(forwardResult.ok);
    assert(reverseResult.ok);
    assert(permutedResult.ok);


    assert(
        wholeResult.output
        == forwardResult.output
    );

    assert(
        forwardResult.output
        == reverseResult.output
    );

    assert(
        forwardResult.output
        == permutedResult.output
    );


    assert(
        wholeResult.accounting.workUnitsStarted
        == 1
    );

    assert(
        wholeResult.accounting.workUnitsCompleted
        == 1
    );

    assert(
        wholeResult.accounting.releases
        == 1
    );

    assert(
        wholeResult.accounting.currentResidentRasterBytes
        == 0
    );


    foreach (
        const result;
        [
            forwardResult,
            reverseResult,
            permutedResult
        ]
    )
    {
        assert(
            result.accounting.workUnitsConsidered
            == forward.length
        );

        assert(
            result.accounting.workUnitsStarted
            == forward.length
        );

        assert(
            result.accounting.workUnitsCompleted
            == forward.length
        );

        assert(
            result.accounting.materializationsStarted
            == forward.length
        );

        assert(
            result.accounting.materializationsCompleted
            == forward.length
        );

        assert(
            result.accounting.operationExecutionsStarted
            == forward.length
        );

        assert(
            result.accounting.operationExecutionsCompleted
            == forward.length
        );

        assert(
            result.accounting.releases
            == forward.length
        );

        assert(
            result.accounting.currentResidentRasterBytes
            == 0
        );

        assert(
            result.accounting.peakResidentRasterBytes
            != 0
        );
    }


    /*
     * Compare the successful R0.4a result against the pre-existing R0.3
     * per-task execution oracle only after lifecycle execution has completed.
     */
    foreach (const task; forward)
    {
        assert(
            taskOutputMatchesR03Oracle(
                logicalExtent,
                requestedOutput,
                task,
                forwardResult.output
            )
        );
    }
}



/*
 * Builds expected completion coverage for a bounded test fixture.
 *
 * This is a test oracle only.
 */
private ubyte[] expectedCoverage(
    Region2D requestedOutput,
    scope const(Region2D)[] completedTasks
)
@safe
{
    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    auto expected =
        new ubyte[sampleCount];


    foreach (const task; completedTasks)
    {
        const relativeX =
            task.x
            - requestedOutput.x;

        const relativeY =
            task.y
            - requestedOutput.y;


        foreach (localY; 0 .. task.height)
        {
            foreach (localX; 0 .. task.width)
            {
                const index =
                    (relativeY + localY)
                        * requestedOutput.width
                    + relativeX
                    + localX;

                assert(index < expected.length);
                assert(expected[index] == 0);

                expected[index] = 1;
            }
        }
    }

    return expected;
}


/*
 * H3 — deterministic materialization failure.
 *
 * The third non-empty work unit fails before a usable resident raster exists.
 *
 * The first two work units remain completed research state, later work does
 * not start, the request is not complete and final local residency is zero.
 */
unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            100,
            100
        );

    const requestedOutput =
        Region2D(
            1020,
            2030,
            8,
            4
        );

    const Region2D[4] tasks =
    [
        Region2D(1020, 2030, 8, 1),
        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),
        Region2D(1020, 2033, 8, 1)
    ];


    auto result =
        executeSynchronousNeighbourhoodImpl(
            logicalExtent,
            requestedOutput,
            tasks[],
            FailureInjection(
                FailureInjectionKind.materialization,
                3
            ),
            CancellationInjection.init
        );


    assert(!result.ok);
    assert(!result.requestCompleted);

    assert(
        result.termination
        == TerminationReason.failed
    );

    assert(
        result.error
        == SynchronousExecutionError.workUnitFailed
    );

    assert(
        result.workUnitError
        == WorkUnitError.materializationFailed
    );


    assert(
        result.accounting.workUnitsConsidered
        == 3
    );

    assert(
        result.accounting.workUnitsStarted
        == 3
    );

    assert(
        result.accounting.workUnitsCompleted
        == 2
    );


    assert(
        result.accounting.materializationsStarted
        == 3
    );

    assert(
        result.accounting.materializationsCompleted
        == 2
    );


    assert(
        result.accounting.operationExecutionsStarted
        == 2
    );

    assert(
        result.accounting.operationExecutionsCompleted
        == 2
    );


    assert(
        result.accounting.releases
        == 2
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );


    enum size_t expectedCompletedPixels =
        8 + 3 * 2;

    assert(
        result.accounting.completedOutputPixels
        == expectedCompletedPixels
    );


    const completedPrefix =
        tasks[0 .. 2];

    assert(
        result.completedCoverage
        == expectedCoverage(
            requestedOutput,
            completedPrefix
        )
    );


    foreach (const task; completedPrefix)
    {
        assert(
            taskOutputMatchesR03Oracle(
                logicalExtent,
                requestedOutput,
                task,
                result.output
            )
        );
    }
}


/*
 * H4 — deterministic operation failure.
 *
 * The third non-empty work unit successfully materializes its source, reaches
 * the operation boundary and then fails before work-unit completion.
 *
 * Its resident raster must still be released.
 */
unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            100,
            100
        );

    const requestedOutput =
        Region2D(
            1020,
            2030,
            8,
            4
        );

    const Region2D[4] tasks =
    [
        Region2D(1020, 2030, 8, 1),
        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),
        Region2D(1020, 2033, 8, 1)
    ];


    auto result =
        executeSynchronousNeighbourhoodImpl(
            logicalExtent,
            requestedOutput,
            tasks[],
            FailureInjection(
                FailureInjectionKind.operation,
                3
            ),
            CancellationInjection.init
        );


    assert(!result.ok);
    assert(!result.requestCompleted);

    assert(
        result.termination
        == TerminationReason.failed
    );

    assert(
        result.error
        == SynchronousExecutionError.workUnitFailed
    );

    assert(
        result.workUnitError
        == WorkUnitError.operationFailed
    );


    assert(
        result.accounting.workUnitsConsidered
        == 3
    );

    assert(
        result.accounting.workUnitsStarted
        == 3
    );

    assert(
        result.accounting.workUnitsCompleted
        == 2
    );


    assert(
        result.accounting.materializationsStarted
        == 3
    );

    assert(
        result.accounting.materializationsCompleted
        == 3
    );


    assert(
        result.accounting.operationExecutionsStarted
        == 3
    );

    assert(
        result.accounting.operationExecutionsCompleted
        == 2
    );


    assert(
        result.accounting.releases
        == 3
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );


    enum size_t expectedCompletedPixels =
        8 + 3 * 2;

    assert(
        result.accounting.completedOutputPixels
        == expectedCompletedPixels
    );


    const completedPrefix =
        tasks[0 .. 2];

    assert(
        result.completedCoverage
        == expectedCoverage(
            requestedOutput,
            completedPrefix
        )
    );


    foreach (const task; completedPrefix)
    {
        assert(
            taskOutputMatchesR03Oracle(
                logicalExtent,
                requestedOutput,
                task,
                result.output
            )
        );
    }
}



/*
 * Shared H5 cancellation fixture.
 */
private enum Region2D[4] cancellationTasks =
[
    Region2D(1020, 2030, 8, 1),
    Region2D(1020, 2031, 3, 2),
    Region2D(1023, 2031, 5, 2),
    Region2D(1020, 2033, 8, 1)
];


private enum Region2D cancellationLogicalExtent =
    Region2D(
        1000,
        2000,
        100,
        100
    );


private enum Region2D cancellationRequestedOutput =
    Region2D(
        1020,
        2030,
        8,
        4
    );


/*
 * Verifies the common H5 cancellation result for a completed prefix.
 */
private void verifyCancelledPrefix(
    SynchronousExecutionResult result,
    size_t completedWorkUnits
)
@safe
{
    assert(!result.ok);
    assert(!result.requestCompleted);

    assert(
        result.termination
        == TerminationReason.cancelled
    );

    assert(
        result.error
        == SynchronousExecutionError.none
    );

    assert(
        result.workUnitError
        == WorkUnitError.none
    );


    assert(
        result.accounting.workUnitsConsidered
        == completedWorkUnits
    );

    assert(
        result.accounting.workUnitsStarted
        == completedWorkUnits
    );

    assert(
        result.accounting.workUnitsCompleted
        == completedWorkUnits
    );


    assert(
        result.accounting.materializationsStarted
        == completedWorkUnits
    );

    assert(
        result.accounting.materializationsCompleted
        == completedWorkUnits
    );


    assert(
        result.accounting.operationExecutionsStarted
        == completedWorkUnits
    );

    assert(
        result.accounting.operationExecutionsCompleted
        == completedWorkUnits
    );


    assert(
        result.accounting.releases
        == completedWorkUnits
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );


    size_t expectedPixels = 0;

    foreach (
        const task;
        cancellationTasks[
            0 .. completedWorkUnits
        ]
    )
    {
        expectedPixels +=
            task.width * task.height;
    }

    assert(
        result.accounting.completedOutputPixels
        == expectedPixels
    );


    assert(
        result.completedCoverage
        == expectedCoverage(
            cancellationRequestedOutput,
            cancellationTasks[
                0 .. completedWorkUnits
            ]
        )
    );


    foreach (
        const task;
        cancellationTasks[
            0 .. completedWorkUnits
        ]
    )
    {
        assert(
            taskOutputMatchesR03Oracle(
                cancellationLogicalExtent,
                cancellationRequestedOutput,
                task,
                result.output
            )
        );
    }
}


/*
 * H5 — cancellation before the first work unit.
 *
 * No work unit is considered, started or materialized.
 */
unittest
{
    auto result =
        executeSynchronousNeighbourhoodImpl(
            cancellationLogicalExtent,
            cancellationRequestedOutput,
            cancellationTasks[],
            FailureInjection.init,
            CancellationInjection(1)
        );


    verifyCancelledPrefix(
        result,
        0
    );


    assert(
        result.accounting.peakResidentRasterBytes
        == 0
    );
}


/*
 * H5 — cancellation after a completed prefix.
 *
 * Work units 1 and 2 complete normally.
 *
 * Cancellation is then observed before work unit 3 begins.
 */
unittest
{
    auto result =
        executeSynchronousNeighbourhoodImpl(
            cancellationLogicalExtent,
            cancellationRequestedOutput,
            cancellationTasks[],
            FailureInjection.init,
            CancellationInjection(3)
        );


    verifyCancelledPrefix(
        result,
        2
    );


    assert(
        result.accounting.peakResidentRasterBytes
        != 0
    );
}


/*
 * H5 — cancellation immediately before the final work unit.
 *
 * Work units 1 through 3 complete normally.
 *
 * The final work unit is never considered or started.
 */
unittest
{
    auto result =
        executeSynchronousNeighbourhoodImpl(
            cancellationLogicalExtent,
            cancellationRequestedOutput,
            cancellationTasks[],
            FailureInjection.init,
            CancellationInjection(4)
        );


    verifyCancelledPrefix(
        result,
        3
    );


    assert(
        result.accounting.peakResidentRasterBytes
        != 0
    );
}


/*
 * Empty requested output remains a successful zero-work request.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            30
        );

    const requestedOutput =
        Region2D(
            110,
            215,
            0,
            0
        );

    const Region2D[] noTasks;


    auto result =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            noTasks
        );


    assert(result.ok);
    assert(result.requestCompleted);

    assert(
        result.termination
        == TerminationReason.completed
    );

    assert(result.output.length == 0);
    assert(result.completedCoverage.length == 0);

    assert(
        result.accounting
        == SynchronousExecutionAccounting.init
    );
}
