module scheduling_policy_oracle;


/++
    R0.4c research-local policy class.

    The names are test metadata only. They are not a proposed production enum.
+/
enum PolicyClass : ubyte
{
    throughput,
    interactive
}


/++
    Minimal ready-work metadata for deterministic policy research.

    None of these fields belongs to Region2D, RasterView or a raster operation
    API.
+/
struct ReadyWork
{
    size_t stableWorkUnitId;
    size_t readyOrdinal;

    PolicyClass policyClass;

    int priority;
}


/++
    R0.4c research-only policy error.

    FIFO requires stable work identity and ready ordinal to be unique inside
    one ready set. Ambiguous input is rejected instead of silently introducing
    a secondary ordering rule.
+/
enum PolicyOracleError : ubyte
{
    none,

    duplicateWorkUnitId,
    duplicateReadyOrdinal,

    internalFailure
}


/++
    Deterministic dispatch trace returned by the policy oracle.
+/
struct DispatchTrace
{
    PolicyOracleError error =
        PolicyOracleError.internalFailure;

    size_t[] workUnitIds;
    size_t[] readyOrdinals;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == PolicyOracleError.none;
    }
}


private PolicyOracleError validateReadySet(
    scope const(ReadyWork)[] ready
)
@safe
pure
nothrow
@nogc
{
    foreach (left; 0 .. ready.length)
    {
        foreach (right; left + 1 .. ready.length)
        {
            if (
                ready[left].stableWorkUnitId
                == ready[right].stableWorkUnitId
            )
            {
                return PolicyOracleError.duplicateWorkUnitId;
            }


            if (
                ready[left].readyOrdinal
                == ready[right].readyOrdinal
            )
            {
                return PolicyOracleError.duplicateReadyOrdinal;
            }
        }
    }


    return PolicyOracleError.none;
}


/++
    P0 FIFO policy.

    FIFO means:

        select the lowest readyOrdinal first

    policyClass and priority are deliberately ignored in R0.4c-1.

    The implementation is intentionally simple O(n^2) research code. It is a
    semantic oracle, not a production queue implementation.
+/
DispatchTrace dispatchFifo(
    scope const(ReadyWork)[] ready
)
@safe
{
    DispatchTrace result;


    const validationError =
        validateReadySet(
            ready
        );


    if (
        validationError
        != PolicyOracleError.none
    )
    {
        result.error =
            validationError;

        return result;
    }


    result.workUnitIds =
        new size_t[ready.length];

    result.readyOrdinals =
        new size_t[ready.length];


    if (ready.length == 0)
    {
        result.error =
            PolicyOracleError.none;

        return result;
    }


    auto selected =
        new bool[ready.length];


    foreach (dispatchOrdinal; 0 .. ready.length)
    {
        size_t selectedIndex =
            size_t.max;

        size_t selectedReadyOrdinal =
            size_t.max;


        foreach (candidateIndex; 0 .. ready.length)
        {
            if (selected[candidateIndex])
            {
                continue;
            }


            const candidateReadyOrdinal =
                ready[candidateIndex]
                    .readyOrdinal;


            if (
                selectedIndex == size_t.max
                || candidateReadyOrdinal
                    < selectedReadyOrdinal
            )
            {
                selectedIndex =
                    candidateIndex;

                selectedReadyOrdinal =
                    candidateReadyOrdinal;
            }
        }


        if (selectedIndex == size_t.max)
        {
            result.error =
                PolicyOracleError.internalFailure;

            return result;
        }


        selected[selectedIndex] = true;


        result.workUnitIds[dispatchOrdinal] =
            ready[selectedIndex]
                .stableWorkUnitId;

        result.readyOrdinals[dispatchOrdinal] =
            ready[selectedIndex]
                .readyOrdinal;
    }


    result.error =
        PolicyOracleError.none;

    return result;
}


/*
 * R0.4c-1 FIFO baseline.
 *
 * Input array order, priority and policy class are deliberately different from
 * ready order.
 *
 * Expected dispatch order is determined solely by readyOrdinal.
 */
unittest
{
    const ReadyWork[6] ready =
    [
        ReadyWork(
            105,
            5,
            PolicyClass.interactive,
            500
        ),

        ReadyWork(
            102,
            2,
            PolicyClass.throughput,
            900
        ),

        ReadyWork(
            100,
            0,
            PolicyClass.throughput,
            -100
        ),

        ReadyWork(
            104,
            4,
            PolicyClass.throughput,
            1000
        ),

        ReadyWork(
            101,
            1,
            PolicyClass.interactive,
            -500
        ),

        ReadyWork(
            103,
            3,
            PolicyClass.interactive,
            0
        )
    ];


    auto trace =
        dispatchFifo(
            ready[]
        );


    assert(trace.ok);


    const size_t[6] expectedWorkUnitIds =
    [
        100,
        101,
        102,
        103,
        104,
        105
    ];


    const size_t[6] expectedReadyOrdinals =
    [
        0,
        1,
        2,
        3,
        4,
        5
    ];


    assert(
        trace.workUnitIds
        == expectedWorkUnitIds[]
    );

    assert(
        trace.readyOrdinals
        == expectedReadyOrdinals[]
    );
}


/*
 * FIFO remains stable when every work item has equal class/priority metadata.
 */
unittest
{
    const ReadyWork[4] ready =
    [
        ReadyWork(
            13,
            3,
            PolicyClass.throughput,
            7
        ),

        ReadyWork(
            10,
            0,
            PolicyClass.throughput,
            7
        ),

        ReadyWork(
            12,
            2,
            PolicyClass.throughput,
            7
        ),

        ReadyWork(
            11,
            1,
            PolicyClass.throughput,
            7
        )
    ];


    auto trace =
        dispatchFifo(
            ready[]
        );


    assert(trace.ok);


    const size_t[4] expected =
    [
        10,
        11,
        12,
        13
    ];


    assert(
        trace.workUnitIds
        == expected[]
    );
}


/*
 * Empty ready set is a valid zero-dispatch state.
 */
unittest
{
    const ReadyWork[] ready;


    auto trace =
        dispatchFifo(
            ready
        );


    assert(trace.ok);

    assert(trace.workUnitIds.length == 0);
    assert(trace.readyOrdinals.length == 0);
}


/*
 * Ambiguous identity/readiness metadata is rejected rather than repaired by
 * an undocumented secondary ordering rule.
 */
unittest
{
    const ReadyWork[2] duplicateId =
    [
        ReadyWork(
            7,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            7,
            1,
            PolicyClass.interactive,
            100
        )
    ];


    auto duplicateIdTrace =
        dispatchFifo(
            duplicateId[]
        );


    assert(!duplicateIdTrace.ok);

    assert(
        duplicateIdTrace.error
        == PolicyOracleError.duplicateWorkUnitId
    );


    const ReadyWork[2] duplicateReadyOrdinal =
    [
        ReadyWork(
            7,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            8,
            0,
            PolicyClass.interactive,
            100
        )
    ];


    auto duplicateReadyTrace =
        dispatchFifo(
            duplicateReadyOrdinal[]
        );


    assert(!duplicateReadyTrace.ok);

    assert(
        duplicateReadyTrace.error
        == PolicyOracleError.duplicateReadyOrdinal
    );
}
