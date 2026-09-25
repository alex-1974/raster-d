module raster_policy_integration;

import raster.region :
    Region2D;

import synchronous_execution :
    executeSynchronousNeighbourhood;

import bounded_parallel_execution :
    executeBoundedParallelNeighbourhood;

import scheduling_policy_oracle :
    BoundedInteractiveBurstState,
    DispatchTrace,
    PolicyClass,
    ReadyWork,
    dispatchFifo,
    dispatchStrictPriority,
    selectBoundedInteractiveBurst;


/*
 * Reorders one legal decomposition according to stable work-unit IDs returned
 * by a deterministic policy trace.
 *
 * For the R0.4c integration fixture stableWorkUnitId is an index into the
 * immutable canonical decomposition.
 */
private Region2D[] reorderTasks(
    scope const(Region2D)[] canonicalTasks,
    scope const(size_t)[] workUnitIds
)
@safe
{
    if (
        workUnitIds.length
        != canonicalTasks.length
    )
    {
        return null;
    }


    auto reordered =
        new Region2D[canonicalTasks.length];

    auto seen =
        new bool[canonicalTasks.length];


    foreach (
        dispatchOrdinal,
        workUnitId;
        workUnitIds
    )
    {
        if (
            workUnitId >= canonicalTasks.length
            || seen[workUnitId]
        )
        {
            return null;
        }


        seen[workUnitId] = true;

        reordered[dispatchOrdinal] =
            canonicalTasks[workUnitId];
    }


    foreach (wasSeen; seen)
    {
        if (!wasSeen)
        {
            return null;
        }
    }


    return reordered;
}


/*
 * Produces a complete finite dispatch trace using the R0.4c-4 bounded-burst
 * selector.
 *
 * The ready set is finite and static for this integration probe.
 *
 * Selection itself remains entirely inside scheduling_policy_oracle.
 */
private size_t[] dispatchAllBoundedBurst(
    scope const(ReadyWork)[] initialReady,
    size_t maxInteractiveBurst
)
@safe
{
    if (
        initialReady.length != 0
        && maxInteractiveBurst == 0
    )
    {
        return null;
    }


    auto remaining =
        initialReady.dup;

    auto dispatched =
        new size_t[initialReady.length];


    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst =
        maxInteractiveBurst;


    foreach (
        dispatchOrdinal;
        0 .. initialReady.length
    )
    {
        auto selection =
            selectBoundedInteractiveBurst(
                remaining,
                state
            );


        if (
            !selection.ok
            || !selection.hasSelection
        )
        {
            return null;
        }


        dispatched[dispatchOrdinal] =
            selection.stableWorkUnitId;


        size_t selectedIndex =
            size_t.max;


        foreach (
            candidateIndex;
            0 .. remaining.length
        )
        {
            if (
                remaining[candidateIndex]
                    .stableWorkUnitId
                == selection.stableWorkUnitId
            )
            {
                selectedIndex =
                    candidateIndex;

                break;
            }
        }


        if (selectedIndex == size_t.max)
        {
            return null;
        }


        foreach (
            moveIndex;
            selectedIndex + 1
                .. remaining.length
        )
        {
            remaining[moveIndex - 1] =
                remaining[moveIndex];
        }


        remaining.length =
            remaining.length - 1;
    }


    return dispatched;
}


/*
 * R0.4c-6 raster integration.
 *
 * One semantic request and one canonical six-member legal decomposition are
 * reused across:
 *
 *     R0.4a synchronous reference
 *     R0.4c FIFO -> R0.4b bounded parallel
 *     R0.4c strict priority -> R0.4b bounded parallel
 *     R0.4c bounded burst -> R0.4b bounded parallel
 *
 * Scheduling policy changes only the order in which decomposition members are
 * presented to the immutable bounded-parallel executor.
 *
 * Semantic output and coverage must remain identical.
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


    const Region2D[6] canonicalTasks =
    [
        Region2D(
            1020,
            2030,
            8,
            1
        ),

        Region2D(
            1020,
            2031,
            3,
            2
        ),

        Region2D(
            1023,
            2031,
            5,
            2
        ),

        Region2D(
            1020,
            2033,
            5,
            2
        ),

        Region2D(
            1025,
            2033,
            3,
            2
        ),

        Region2D(
            1020,
            2035,
            8,
            1
        )
    ];


    /*
     * The metadata deliberately makes each candidate policy choose a
     * different legal order.
     *
     * stableWorkUnitId maps directly to canonicalTasks index.
     */
    const ReadyWork[6] ready =
    [
        ReadyWork(
            0,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            1,
            1,
            PolicyClass.interactive,
            50
        ),

        ReadyWork(
            2,
            2,
            PolicyClass.throughput,
            10
        ),

        ReadyWork(
            3,
            3,
            PolicyClass.interactive,
            100
        ),

        ReadyWork(
            4,
            4,
            PolicyClass.throughput,
            20
        ),

        ReadyWork(
            5,
            5,
            PolicyClass.interactive,
            80
        )
    ];


    auto synchronous =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            canonicalTasks[]
        );

    assert(synchronous.ok);
    assert(synchronous.requestCompleted);


    auto fifoTrace =
        dispatchFifo(
            ready[]
        );

    auto strictTrace =
        dispatchStrictPriority(
            ready[]
        );


    assert(fifoTrace.ok);
    assert(strictTrace.ok);


    auto boundedBurstIds =
        dispatchAllBoundedBurst(
            ready[],
            2
        );


    assert(
        boundedBurstIds.length
        == canonicalTasks.length
    );


    const size_t[6] expectedFifo =
    [
        0,
        1,
        2,
        3,
        4,
        5
    ];

    const size_t[6] expectedStrict =
    [
        3,
        5,
        1,
        4,
        2,
        0
    ];

    const size_t[6] expectedBoundedBurst =
    [
        3,
        5,
        4,
        1,
        2,
        0
    ];


    assert(
        fifoTrace.workUnitIds
        == expectedFifo[]
    );

    assert(
        strictTrace.workUnitIds
        == expectedStrict[]
    );

    assert(
        boundedBurstIds
        == expectedBoundedBurst[]
    );


    /*
     * The three policy orders are observably distinct.
     */
    assert(
        fifoTrace.workUnitIds
        != strictTrace.workUnitIds
    );

    assert(
        fifoTrace.workUnitIds
        != boundedBurstIds
    );

    assert(
        strictTrace.workUnitIds
        != boundedBurstIds
    );


    auto fifoTasks =
        reorderTasks(
            canonicalTasks[],
            fifoTrace.workUnitIds
        );

    auto strictTasks =
        reorderTasks(
            canonicalTasks[],
            strictTrace.workUnitIds
        );

    auto boundedBurstTasks =
        reorderTasks(
            canonicalTasks[],
            boundedBurstIds
        );


    assert(
        fifoTasks.length
        == canonicalTasks.length
    );

    assert(
        strictTasks.length
        == canonicalTasks.length
    );

    assert(
        boundedBurstTasks.length
        == canonicalTasks.length
    );


    enum size_t maxActiveWorkUnits = 2;


    auto fifoResult =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            fifoTasks,
            maxActiveWorkUnits
        );

    auto strictResult =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            strictTasks,
            maxActiveWorkUnits
        );

    auto boundedBurstResult =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            boundedBurstTasks,
            maxActiveWorkUnits
        );


    assert(fifoResult.ok);
    assert(strictResult.ok);
    assert(boundedBurstResult.ok);


    assert(fifoResult.requestCompleted);
    assert(strictResult.requestCompleted);
    assert(boundedBurstResult.requestCompleted);


    /*
     * Policy order does not change semantic raster output.
     */
    assert(
        fifoResult.output
        == synchronous.output
    );

    assert(
        strictResult.output
        == synchronous.output
    );

    assert(
        boundedBurstResult.output
        == synchronous.output
    );


    assert(
        fifoResult.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        strictResult.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        boundedBurstResult.completedCoverage
        == synchronous.completedCoverage
    );


    /*
     * Policy selection does not weaken the R0.4b active-work bound.
     */
    assert(
        fifoResult.accounting.maxActiveWorkUnits
        == maxActiveWorkUnits
    );

    assert(
        strictResult.accounting.maxActiveWorkUnits
        == maxActiveWorkUnits
    );

    assert(
        boundedBurstResult.accounting.maxActiveWorkUnits
        == maxActiveWorkUnits
    );


    assert(
        fifoResult.accounting.peakActiveWorkUnits
        == maxActiveWorkUnits
    );

    assert(
        strictResult.accounting.peakActiveWorkUnits
        == maxActiveWorkUnits
    );

    assert(
        boundedBurstResult.accounting.peakActiveWorkUnits
        == maxActiveWorkUnits
    );


    assert(
        fifoResult.accounting.peakActiveWorkUnits
        <= fifoResult.accounting.maxActiveWorkUnits
    );

    assert(
        strictResult.accounting.peakActiveWorkUnits
        <= strictResult.accounting.maxActiveWorkUnits
    );

    assert(
        boundedBurstResult.accounting.peakActiveWorkUnits
        <= boundedBurstResult.accounting.maxActiveWorkUnits
    );


    /*
     * Every integrated policy run releases its work-unit-local residency.
     */
    assert(
        fifoResult.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        strictResult.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        boundedBurstResult.accounting.currentResidentRasterBytes
        == 0
    );
}
