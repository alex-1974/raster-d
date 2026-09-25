module bounded_parallel_execution;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import raster.region :
    Region2D;

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

import synchronous_execution :
    executeSynchronousNeighbourhood;


enum BoundedParallelSuccessError : ubyte
{
    none,

    invalidRequest,
    invalidDecomposition,
    invalidParallelism,

    workerFailed,
    internalFailure
}


struct BoundedParallelSuccessAccounting
{
    size_t maxActiveWorkUnits;

    size_t batchesStarted;

    size_t workUnitsRequired;
    size_t workUnitsStarted;
    size_t workUnitsCompleted;

    size_t materializationsStarted;
    size_t materializationsCompleted;

    size_t operationExecutionsStarted;
    size_t operationExecutionsCompleted;

    size_t currentActiveWorkUnits;
    size_t peakActiveWorkUnits;

    size_t peakOperationReadyWorkUnits;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;

    size_t completedOutputPixels;

    size_t releases;
}


struct BoundedParallelSuccessResult
{
    BoundedParallelSuccessError error =
        BoundedParallelSuccessError.internalFailure;

    DecompositionIssue decompositionIssue =
        DecompositionIssue.none;

    bool requestCompleted;

    ubyte[] output;
    ubyte[] completedCoverage;

    BoundedParallelSuccessAccounting accounting;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == BoundedParallelSuccessError.none
            && requestCompleted;
    }
}


private enum ParallelWorkError : ubyte
{
    none,

    invalidTask,
    dependencyDerivationFailed,
    unsatisfiedContext,
    materializationFailed,
    sampleReadFailed,

    internalFailure
}


private struct ParallelWorkResult
{
    ParallelWorkError error =
        ParallelWorkError.internalFailure;

    bool materializationStarted;
    bool materializationCompleted;

    bool operationStarted;
    bool operationCompleted;

    size_t residentBytes;

    ubyte[] output;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == ParallelWorkError.none;
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


/*
 * R0.4b intentionally reuses the established R0.3 dependency,
 * materialization and weighted-kernel implementations.
 *
 * This helper contains only resident-coordinate orchestration needed to
 * execute the already-defined kernel against an already materialized raster.
 *
 * It is experiment-local and is not a production execution primitive.
 */
private bool tryExecuteResidentNeighbourhood(
    Region2D outputTask,
    ExpandedDependency dependency,
    ref MaterializedUbyteRaster source,
    ref ubyte[] output
)
@safe
{
    if (
        source.logicalRequest
        != dependency.validInput
    )
    {
        return false;
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
        return false;
    }


    if (
        dependency.validInput.x
            > outputTask.x
        || dependency.validInput.y
            > outputTask.y
    )
    {
        return false;
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
        return false;
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
        return false;
    }


    if (
        outputTask.width != 0
        && outputTask.height
            > size_t.max / outputTask.width
    )
    {
        return false;
    }


    const sampleCount =
        outputTask.width
        * outputTask.height;

    if (sampleCount == 0)
    {
        return false;
    }


    output =
        new ubyte[sampleCount];


    foreach (localY; 0 .. outputTask.height)
    {
        const centerY =
            sourceBaseY
            + localY;

        foreach (localX; 0 .. outputTask.width)
        {
            const centerX =
                sourceBaseX
                + localX;


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
                return false;
            }


            const outputIndex =
                localY * outputTask.width
                + localX;

            output[outputIndex] =
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

    return true;
}


/*
 * One success-path worker.
 *
 * The coordinator barriers are research instrumentation. They prove that
 * multiple successful materializations are resident concurrently and that
 * multiple work units reach the operation boundary concurrently without
 * sleep or wall-clock assumptions.
 */
private class SuccessWorker
{
    Region2D logicalExtent;
    Region2D outputTask;

    Barrier residentReadyGate;
    Barrier residentReleaseGate;
    Barrier operationReadyGate;

    ParallelWorkResult result;


    this(
        Region2D logicalExtent,
        Region2D outputTask,
        Barrier residentReadyGate,
        Barrier residentReleaseGate,
        Barrier operationReadyGate
    )
    {
        this.logicalExtent =
            logicalExtent;

        this.outputTask =
            outputTask;

        this.residentReadyGate =
            residentReadyGate;

        this.residentReleaseGate =
            residentReleaseGate;

        this.operationReadyGate =
            operationReadyGate;
    }


    private void passFailureGates()
    {
        residentReadyGate.wait();
        residentReleaseGate.wait();
        operationReadyGate.wait();
    }


    void run()
    {
        if (
            !outputTask.hasRepresentableExtent()
            || outputTask.empty()
        )
        {
            result.error =
                ParallelWorkError.invalidTask;

            passFailureGates();
            return;
        }


        ExpandedDependency dependency;

        if (!tryExpandDependency(
            logicalExtent,
            outputTask,
            neighbourhoodMargins(),
            dependency
        ))
        {
            result.error =
                ParallelWorkError.dependencyDerivationFailed;

            passFailureGates();
            return;
        }


        if (
            dependency.contextDeficit
            != ContextDeficit.init
        )
        {
            result.error =
                ParallelWorkError.unsatisfiedContext;

            passFailureGates();
            return;
        }


        result.materializationStarted = true;


        auto source =
            materializeProcedural(
                logicalExtent,
                dependency.validInput
            );


        if (!source.ok)
        {
            result.error =
                ParallelWorkError.materializationFailed;

            passFailureGates();
            return;
        }


        result.materializationCompleted = true;

        result.residentBytes =
            source.materialized.residentBytes;


        residentReadyGate.wait();
        residentReleaseGate.wait();


        result.operationStarted = true;

        operationReadyGate.wait();


        ubyte[] output;

        if (!tryExecuteResidentNeighbourhood(
            outputTask,
            dependency,
            source.materialized,
            output
        ))
        {
            result.error =
                ParallelWorkError.sampleReadFailed;

            return;
        }


        result.output =
            output;

        result.operationCompleted = true;

        result.error =
            ParallelWorkError.none;
    }
}


private void updatePeak(
    ref size_t peak,
    size_t current
)
@safe
pure
nothrow
@nogc
{
    if (current > peak)
    {
        peak = current;
    }
}


/++
    Executes one legal decomposition in bounded batches.

    R0.4b-1 deliberately uses disposable batch-local OS threads rather than a
    reusable worker-pool abstraction.

    The goal is to establish bounded-parallel semantics before selecting a
    scheduler architecture.
+/
BoundedParallelSuccessResult executeBoundedParallelNeighbourhood(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks,
    size_t maxActiveWorkUnits
)
{
    BoundedParallelSuccessResult result;

    result.accounting.maxActiveWorkUnits =
        maxActiveWorkUnits;

    result.accounting.workUnitsRequired =
        tasks.length;


    if (
        maxActiveWorkUnits == 0
        || maxActiveWorkUnits
            >= cast(size_t) uint.max
    )
    {
        result.error =
            BoundedParallelSuccessError.invalidParallelism;

        return result;
    }


    if (
        !logicalExtent.hasRepresentableExtent()
        || !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.error =
            BoundedParallelSuccessError.invalidRequest;

        return result;
    }


    if (
        requestedOutput.width != 0
        && requestedOutput.height
            > size_t.max / requestedOutput.width
    )
    {
        result.error =
            BoundedParallelSuccessError.invalidRequest;

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
            BoundedParallelSuccessError.invalidDecomposition;

        result.decompositionIssue =
            decompositionIssue;

        return result;
    }


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.completedCoverage =
        new ubyte[sampleCount];


    size_t nextTask = 0;


    while (nextTask < tasks.length)
    {
        size_t batchSize =
            tasks.length - nextTask;

        if (batchSize > maxActiveWorkUnits)
        {
            batchSize =
                maxActiveWorkUnits;
        }


        const barrierLimit =
            cast(uint) (batchSize + 1);

        auto residentReadyGate =
            new Barrier(barrierLimit);

        auto residentReleaseGate =
            new Barrier(barrierLimit);

        auto operationReadyGate =
            new Barrier(barrierLimit);


        auto workers =
            new SuccessWorker[batchSize];

        auto threads =
            new Thread[batchSize];


        ++result.accounting.batchesStarted;


        foreach (localIndex; 0 .. batchSize)
        {
            const taskIndex =
                nextTask + localIndex;

            auto worker =
                new SuccessWorker(
                    logicalExtent,
                    tasks[taskIndex],
                    residentReadyGate,
                    residentReleaseGate,
                    operationReadyGate
                );

            workers[localIndex] =
                worker;


            auto thread =
                new Thread(
                    &worker.run
                );

            threads[localIndex] =
                thread;

            thread.start();

            ++result.accounting.workUnitsStarted;
        }


        residentReadyGate.wait();


        size_t batchMaterializationsStarted = 0;
        size_t batchMaterializationsCompleted = 0;
        size_t batchResidentBytes = 0;


        foreach (worker; workers)
        {
            if (worker.result.materializationStarted)
            {
                ++batchMaterializationsStarted;
            }

            if (worker.result.materializationCompleted)
            {
                ++batchMaterializationsCompleted;

                batchResidentBytes +=
                    worker.result.residentBytes;
            }
        }


        result.accounting.materializationsStarted +=
            batchMaterializationsStarted;

        result.accounting.materializationsCompleted +=
            batchMaterializationsCompleted;


        result.accounting.currentActiveWorkUnits =
            batchSize;

        updatePeak(
            result.accounting.peakActiveWorkUnits,
            batchSize
        );


        result.accounting.currentResidentRasterBytes =
            batchResidentBytes;

        updatePeak(
            result.accounting.peakResidentRasterBytes,
            batchResidentBytes
        );


        residentReleaseGate.wait();

        operationReadyGate.wait();


        size_t batchOperationsStarted = 0;

        foreach (worker; workers)
        {
            if (worker.result.operationStarted)
            {
                ++batchOperationsStarted;
            }
        }


        result.accounting.operationExecutionsStarted +=
            batchOperationsStarted;

        updatePeak(
            result.accounting.peakOperationReadyWorkUnits,
            batchOperationsStarted
        );


        foreach (thread; threads)
        {
            thread.join();
        }


        size_t batchOperationsCompleted = 0;
        size_t batchWorkUnitsCompleted = 0;


        foreach (worker; workers)
        {
            if (worker.result.operationCompleted)
            {
                ++batchOperationsCompleted;
            }

            if (worker.result.ok)
            {
                ++batchWorkUnitsCompleted;
            }
        }


        result.accounting.operationExecutionsCompleted +=
            batchOperationsCompleted;

        result.accounting.workUnitsCompleted +=
            batchWorkUnitsCompleted;


        result.accounting.releases +=
            batchMaterializationsCompleted;

        result.accounting.currentResidentRasterBytes = 0;
        result.accounting.currentActiveWorkUnits = 0;


        if (
            batchMaterializationsStarted
                != batchSize
            || batchMaterializationsCompleted
                != batchSize
            || batchOperationsStarted
                != batchSize
            || batchOperationsCompleted
                != batchSize
            || batchWorkUnitsCompleted
                != batchSize
        )
        {
            result.error =
                BoundedParallelSuccessError.workerFailed;

            return result;
        }


        foreach (localIndex; 0 .. batchSize)
        {
            const task =
                tasks[
                    nextTask + localIndex
                ];

            const worker =
                workers[localIndex];


            if (
                task.width != 0
                && task.height
                    > size_t.max / task.width
            )
            {
                result.error =
                    BoundedParallelSuccessError.internalFailure;

                return result;
            }


            if (
                worker.result.output.length
                != task.width * task.height
            )
            {
                result.error =
                    BoundedParallelSuccessError.internalFailure;

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
                    const taskOutputIndex =
                        localY * task.width
                        + localX;

                    const requestOutputIndex =
                        (relativeY + localY)
                            * requestedOutput.width
                        + relativeX
                        + localX;


                    if (
                        requestOutputIndex
                        >= result.output.length
                        || result.completedCoverage[
                            requestOutputIndex
                        ] != 0
                    )
                    {
                        result.error =
                            BoundedParallelSuccessError.internalFailure;

                        return result;
                    }


                    result.output[requestOutputIndex] =
                        worker.result.output[
                            taskOutputIndex
                        ];

                    result.completedCoverage[
                        requestOutputIndex
                    ] = 1;

                    ++result.accounting.completedOutputPixels;
                }
            }
        }


        nextTask +=
            batchSize;
    }


    if (
        result.accounting.workUnitsStarted
            != result.accounting.workUnitsRequired
        || result.accounting.workUnitsCompleted
            != result.accounting.workUnitsRequired
        || result.accounting.materializationsStarted
            != result.accounting.workUnitsRequired
        || result.accounting.materializationsCompleted
            != result.accounting.workUnitsRequired
        || result.accounting.operationExecutionsStarted
            != result.accounting.workUnitsRequired
        || result.accounting.operationExecutionsCompleted
            != result.accounting.workUnitsRequired
        || result.accounting.releases
            != result.accounting.workUnitsRequired
        || result.accounting.completedOutputPixels
            != sampleCount
        || result.accounting.currentActiveWorkUnits
            != 0
        || result.accounting.currentResidentRasterBytes
            != 0
    )
    {
        result.error =
            BoundedParallelSuccessError.internalFailure;

        return result;
    }


    result.requestCompleted = true;

    result.error =
        BoundedParallelSuccessError.none;

    return result;
}


/*
 * R0.4b-1 bounded success path.
 *
 * The same irregular six-member decomposition used by the R0.4a success
 * evidence is executed with explicit parallel bounds 2 and 3.
 *
 * Deterministic barriers prove that more than one work unit is simultaneously
 * active and that more than one resident source exists at the same time.
 *
 * No sleep or wall-clock timing is used.
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


    const Region2D[6] tasks =
    [
        Region2D(1020, 2030, 8, 1),

        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),

        Region2D(1020, 2033, 5, 2),
        Region2D(1025, 2033, 3, 2),

        Region2D(1020, 2035, 8, 1)
    ];


    auto synchronous =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    assert(synchronous.ok);


    auto parallel2 =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks[],
            2
        );

    auto parallel3 =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks[],
            3
        );


    assert(parallel2.ok);
    assert(parallel3.ok);


    assert(
        parallel2.output
        == synchronous.output
    );

    assert(
        parallel3.output
        == synchronous.output
    );

    assert(
        parallel2.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        parallel3.completedCoverage
        == synchronous.completedCoverage
    );


    assert(
        parallel2.accounting.maxActiveWorkUnits
        == 2
    );

    assert(
        parallel3.accounting.maxActiveWorkUnits
        == 3
    );


    assert(
        parallel2.accounting.peakActiveWorkUnits
        == 2
    );

    assert(
        parallel3.accounting.peakActiveWorkUnits
        == 3
    );


    assert(
        parallel2.accounting.peakOperationReadyWorkUnits
        == 2
    );

    assert(
        parallel3.accounting.peakOperationReadyWorkUnits
        == 3
    );


    assert(
        parallel2.accounting.batchesStarted
        == 3
    );

    assert(
        parallel3.accounting.batchesStarted
        == 2
    );


    foreach (
        result;
        [
            parallel2,
            parallel3
        ]
    )
    {
        assert(result.requestCompleted);

        assert(
            result.accounting.workUnitsRequired
            == tasks.length
        );

        assert(
            result.accounting.workUnitsStarted
            == tasks.length
        );

        assert(
            result.accounting.workUnitsCompleted
            == tasks.length
        );

        assert(
            result.accounting.materializationsStarted
            == tasks.length
        );

        assert(
            result.accounting.materializationsCompleted
            == tasks.length
        );

        assert(
            result.accounting.operationExecutionsStarted
            == tasks.length
        );

        assert(
            result.accounting.operationExecutionsCompleted
            == tasks.length
        );

        assert(
            result.accounting.releases
            == tasks.length
        );

        assert(
            result.accounting.currentActiveWorkUnits
            == 0
        );

        assert(
            result.accounting.currentResidentRasterBytes
            == 0
        );

        assert(
            result.accounting.peakActiveWorkUnits
            > 1
        );

        assert(
            result.accounting.peakActiveWorkUnits
            <= result.accounting.maxActiveWorkUnits
        );

        assert(
            result.accounting.peakOperationReadyWorkUnits
            > 1
        );

        assert(
            result.accounting.peakResidentRasterBytes
            > synchronous.accounting
                .peakResidentRasterBytes
        );

        assert(
            result.accounting.completedOutputPixels
            == requestedOutput.width
                * requestedOutput.height
        );
    }
}
