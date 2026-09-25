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


/++
    P1 strict-priority policy.

    Selection rule:

        highest priority first
        then lowest readyOrdinal

    policyClass remains descriptive metadata in R0.4c-2.

    Strict priority deliberately contains no aging, quota or fairness state.
    Starvation behaviour is investigated separately in R0.4c-3.
+/
DispatchTrace dispatchStrictPriority(
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

        int selectedPriority =
            int.min;

        size_t selectedReadyOrdinal =
            size_t.max;


        foreach (candidateIndex; 0 .. ready.length)
        {
            if (selected[candidateIndex])
            {
                continue;
            }


            const candidatePriority =
                ready[candidateIndex]
                    .priority;

            const candidateReadyOrdinal =
                ready[candidateIndex]
                    .readyOrdinal;


            if (
                selectedIndex == size_t.max
                || candidatePriority
                    > selectedPriority
                || (
                    candidatePriority
                        == selectedPriority
                    && candidateReadyOrdinal
                        < selectedReadyOrdinal
                )
            )
            {
                selectedIndex =
                    candidateIndex;

                selectedPriority =
                    candidatePriority;

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
 * R0.4c-2 strict-priority preference.
 *
 * Input array order and ready order deliberately conflict with priority order.
 *
 * The highest numeric priority must dispatch first.
 */
unittest
{
    const ReadyWork[6] ready =
    [
        ReadyWork(
            200,
            0,
            PolicyClass.throughput,
            10
        ),

        ReadyWork(
            201,
            1,
            PolicyClass.interactive,
            100
        ),

        ReadyWork(
            202,
            2,
            PolicyClass.throughput,
            30
        ),

        ReadyWork(
            203,
            3,
            PolicyClass.interactive,
            80
        ),

        ReadyWork(
            204,
            4,
            PolicyClass.throughput,
            -20
        ),

        ReadyWork(
            205,
            5,
            PolicyClass.interactive,
            50
        )
    ];


    auto trace =
        dispatchStrictPriority(
            ready[]
        );


    assert(trace.ok);


    const size_t[6] expected =
    [
        201,
        203,
        205,
        202,
        200,
        204
    ];


    assert(
        trace.workUnitIds
        == expected[]
    );
}


/*
 * Equal priority uses readyOrdinal as the stable FIFO tie-break.
 *
 * Array order and policy class must not disturb that order.
 */
unittest
{
    const ReadyWork[5] ready =
    [
        ReadyWork(
            304,
            4,
            PolicyClass.interactive,
            42
        ),

        ReadyWork(
            301,
            1,
            PolicyClass.throughput,
            42
        ),

        ReadyWork(
            303,
            3,
            PolicyClass.throughput,
            42
        ),

        ReadyWork(
            300,
            0,
            PolicyClass.interactive,
            42
        ),

        ReadyWork(
            302,
            2,
            PolicyClass.interactive,
            42
        )
    ];


    auto trace =
        dispatchStrictPriority(
            ready[]
        );


    assert(trace.ok);


    const size_t[5] expected =
    [
        300,
        301,
        302,
        303,
        304
    ];


    assert(
        trace.workUnitIds
        == expected[]
    );
}


/*
 * Higher priority wins even when it became ready later.
 *
 * This distinguishes P1 from the FIFO baseline directly.
 */
unittest
{
    const ReadyWork[3] ready =
    [
        ReadyWork(
            400,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            401,
            1,
            PolicyClass.throughput,
            1
        ),

        ReadyWork(
            402,
            2,
            PolicyClass.interactive,
            1000
        )
    ];


    auto fifo =
        dispatchFifo(
            ready[]
        );

    auto strict =
        dispatchStrictPriority(
            ready[]
        );


    assert(fifo.ok);
    assert(strict.ok);


    assert(
        fifo.workUnitIds[0]
        == 400
    );

    assert(
        strict.workUnitIds[0]
        == 402
    );
}


/*
 * Strict priority accepts the full int priority domain.
 */
unittest
{
    const ReadyWork[3] ready =
    [
        ReadyWork(
            500,
            0,
            PolicyClass.throughput,
            int.min
        ),

        ReadyWork(
            501,
            1,
            PolicyClass.interactive,
            int.max
        ),

        ReadyWork(
            502,
            2,
            PolicyClass.throughput,
            0
        )
    ];


    auto trace =
        dispatchStrictPriority(
            ready[]
        );


    assert(trace.ok);


    const size_t[3] expected =
    [
        501,
        502,
        500
    ];


    assert(
        trace.workUnitIds
        == expected[]
    );
}


/*
 * Strict priority shares the same ready-set validity contract as FIFO.
 */
unittest
{
    const ReadyWork[2] duplicateId =
    [
        ReadyWork(
            77,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            77,
            1,
            PolicyClass.interactive,
            100
        )
    ];


    auto duplicateIdTrace =
        dispatchStrictPriority(
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
            77,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            78,
            0,
            PolicyClass.interactive,
            100
        )
    ];


    auto duplicateReadyTrace =
        dispatchStrictPriority(
            duplicateReadyOrdinal[]
        );


    assert(!duplicateReadyTrace.ok);

    assert(
        duplicateReadyTrace.error
        == PolicyOracleError.duplicateReadyOrdinal
    );
}


/*
 * Empty ready set remains a valid zero-dispatch state under P1.
 */
unittest
{
    const ReadyWork[] ready;


    auto trace =
        dispatchStrictPriority(
            ready
        );


    assert(trace.ok);

    assert(trace.workUnitIds.length == 0);
    assert(trace.readyOrdinals.length == 0);
}


/++
    Deterministic R0.4c-3 evidence for strict-priority starvation/bypass.

    One lower-priority throughput work unit remains continuously ready while a
    fresh higher-priority interactive work unit is made ready before every
    dispatch opportunity.

    The probe executes a caller-selected finite number of opportunities.

    If strict priority has no starvation-prevention state, the continuously
    ready lower-priority work unit is bypassed once per opportunity.
+/
struct StrictPriorityStarvationEvidence
{
    PolicyOracleError error =
        PolicyOracleError.internalFailure;

    size_t dispatchOpportunities;
    size_t bypassedOpportunities;

    bool lowerPriorityDispatched;

    size_t[] dispatchedWorkUnitIds;


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


/++
    Simulates sustained higher-priority arrivals for a fixed number of
    deterministic dispatch opportunities.

    This is not a time simulation.

    At each opportunity:

    - work unit size_t.max is the same continuously ready throughput item;
    - one fresh interactive item is ready at higher priority;
    - strict priority chooses exactly one next admission;
    - the throughput item remains ready if it was not chosen.

    The function intentionally has no fairness, aging or quota state.
+/
StrictPriorityStarvationEvidence
probeStrictPrioritySustainedHigherPriority(
    size_t dispatchOpportunities
)
@safe
{
    StrictPriorityStarvationEvidence result;

    result.dispatchOpportunities =
        dispatchOpportunities;

    result.dispatchedWorkUnitIds =
        new size_t[dispatchOpportunities];


    enum size_t lowerPriorityWorkUnitId =
        size_t.max;

    enum int lowerPriority =
        0;

    enum int higherPriority =
        1;


    foreach (
        opportunity;
        0 .. dispatchOpportunities
    )
    {
        /*
         * The lower-priority item has been continuously ready since ordinal 0.
         *
         * A fresh higher-priority item arrives before this dispatch
         * opportunity.
         */
        const ReadyWork[2] ready =
        [
            ReadyWork(
                lowerPriorityWorkUnitId,
                0,
                PolicyClass.throughput,
                lowerPriority
            ),

            ReadyWork(
                opportunity,
                opportunity + 1,
                PolicyClass.interactive,
                higherPriority
            )
        ];


        auto trace =
            dispatchStrictPriority(
                ready[]
            );


        if (
            !trace.ok
            || trace.workUnitIds.length != 2
        )
        {
            result.error =
                PolicyOracleError.internalFailure;

            return result;
        }


        const selectedWorkUnitId =
            trace.workUnitIds[0];

        result.dispatchedWorkUnitIds[
            opportunity
        ] =
            selectedWorkUnitId;


        if (
            selectedWorkUnitId
            == lowerPriorityWorkUnitId
        )
        {
            result.lowerPriorityDispatched = true;

            result.error =
                PolicyOracleError.internalFailure;

            return result;
        }


        ++result.bypassedOpportunities;
    }


    result.error =
        PolicyOracleError.none;

    return result;
}


/*
 * R0.4c-3 strict-priority starvation evidence.
 *
 * The test deliberately evaluates several finite observation horizons.
 *
 * For every requested horizon:
 *
 *     bypassedOpportunities == dispatchOpportunities
 *
 * Therefore strict priority provides no finite bypass bound of its own.
 *
 * This is stronger and more precise than a wall-clock statement such as
 * "the throughput item waited a long time".
 */
unittest
{
    const size_t[5] horizons =
    [
        1,
        2,
        8,
        32,
        128
    ];


    foreach (horizon; horizons)
    {
        auto evidence =
            probeStrictPrioritySustainedHigherPriority(
                horizon
            );


        assert(evidence.ok);

        assert(
            evidence.dispatchOpportunities
            == horizon
        );

        assert(
            evidence.bypassedOpportunities
            == horizon
        );

        assert(
            !evidence.lowerPriorityDispatched
        );

        assert(
            evidence.dispatchedWorkUnitIds.length
            == horizon
        );


        foreach (
            dispatchOrdinal;
            0 .. horizon
        )
        {
            assert(
                evidence.dispatchedWorkUnitIds[
                    dispatchOrdinal
                ]
                == dispatchOrdinal
            );
        }
    }
}


/*
 * The same two-item ready state distinguishes FIFO progress from strict
 * priority bypass without any timing assumption.
 *
 * FIFO services the continuously ready older throughput item first.
 *
 * Strict priority services the newer higher-priority interactive item first.
 */
unittest
{
    const ReadyWork[2] ready =
    [
        ReadyWork(
            900,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            901,
            1,
            PolicyClass.interactive,
            1
        )
    ];


    auto fifo =
        dispatchFifo(
            ready[]
        );

    auto strict =
        dispatchStrictPriority(
            ready[]
        );


    assert(fifo.ok);
    assert(strict.ok);


    assert(
        fifo.workUnitIds[0]
        == 900
    );

    assert(
        strict.workUnitIds[0]
        == 901
    );
}

