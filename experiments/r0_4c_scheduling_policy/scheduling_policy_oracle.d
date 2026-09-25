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

    invalidPolicyConfiguration,

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


/++
    Minimal R0.4c-4 state for bounded interactive preference.

    This is deliberately policy-local state.

    No per-work-unit aging or history is retained.
+/
struct BoundedInteractiveBurstState
{
    size_t maxInteractiveBurst;

    size_t consecutiveInteractiveAdmissions;
}


/++
    One deterministic admission decision for the bounded-burst policy.
+/
struct BoundedBurstSelection
{
    PolicyOracleError error =
        PolicyOracleError.internalFailure;

    bool hasSelection;

    size_t stableWorkUnitId;
    size_t readyOrdinal;

    PolicyClass policyClass;

    int priority;


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


private size_t selectBestInClass(
    scope const(ReadyWork)[] ready,
    PolicyClass policyClass
)
@safe
pure
nothrow
@nogc
{
    size_t selectedIndex =
        size_t.max;

    int selectedPriority =
        int.min;

    size_t selectedReadyOrdinal =
        size_t.max;


    foreach (candidateIndex; 0 .. ready.length)
    {
        if (
            ready[candidateIndex].policyClass
            != policyClass
        )
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


    return selectedIndex;
}


/++
    P2 bounded interactive-burst policy.

    Rule while both classes are ready:

        admit at most maxInteractiveBurst consecutive interactive items
        then admit one throughput item

    Within the chosen class:

        highest priority first
        then lowest readyOrdinal

    If throughput is not ready, interactive admissions do not count as bypasses
    and the burst counter is reset.

    If interactive is not ready, throughput is selected and the burst counter
    is reset.

    This gives a deterministic progress bound only for continuously ready
    throughput work. It is not a CPU-time fairness guarantee.
+/
BoundedBurstSelection selectBoundedInteractiveBurst(
    scope const(ReadyWork)[] ready,
    ref BoundedInteractiveBurstState state
)
@safe
{
    BoundedBurstSelection result;


    if (state.maxInteractiveBurst == 0)
    {
        result.error =
            PolicyOracleError.invalidPolicyConfiguration;

        return result;
    }


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


    if (ready.length == 0)
    {
        state.consecutiveInteractiveAdmissions = 0;

        result.error =
            PolicyOracleError.none;

        return result;
    }


    const interactiveIndex =
        selectBestInClass(
            ready,
            PolicyClass.interactive
        );

    const throughputIndex =
        selectBestInClass(
            ready,
            PolicyClass.throughput
        );


    size_t selectedIndex =
        size_t.max;


    if (
        interactiveIndex == size_t.max
        && throughputIndex == size_t.max
    )
    {
        result.error =
            PolicyOracleError.internalFailure;

        return result;
    }


    if (throughputIndex == size_t.max)
    {
        /*
         * No throughput work is being bypassed.
         */
        selectedIndex =
            interactiveIndex;

        state.consecutiveInteractiveAdmissions = 0;
    }
    else if (interactiveIndex == size_t.max)
    {
        selectedIndex =
            throughputIndex;

        state.consecutiveInteractiveAdmissions = 0;
    }
    else if (
        state.consecutiveInteractiveAdmissions
        < state.maxInteractiveBurst
    )
    {
        selectedIndex =
            interactiveIndex;

        ++state.consecutiveInteractiveAdmissions;
    }
    else
    {
        selectedIndex =
            throughputIndex;

        state.consecutiveInteractiveAdmissions = 0;
    }


    if (selectedIndex == size_t.max)
    {
        result.error =
            PolicyOracleError.internalFailure;

        return result;
    }


    result.hasSelection = true;

    result.stableWorkUnitId =
        ready[selectedIndex]
            .stableWorkUnitId;

    result.readyOrdinal =
        ready[selectedIndex]
            .readyOrdinal;

    result.policyClass =
        ready[selectedIndex]
            .policyClass;

    result.priority =
        ready[selectedIndex]
            .priority;

    result.error =
        PolicyOracleError.none;

    return result;
}


/++
    Deterministic sustained-arrival evidence for P2.

    One throughput work unit remains continuously ready.

    Before every dispatch opportunity one fresh interactive work unit is made
    ready.

    The returned maximum bypass run therefore measures the exact number of
    consecutive interactive admissions while throughput remained ready.
+/
struct BoundedBurstEvidence
{
    PolicyOracleError error =
        PolicyOracleError.internalFailure;

    size_t dispatchOpportunities;

    size_t interactiveAdmissions;
    size_t throughputAdmissions;

    size_t maxObservedThroughputBypass;

    size_t[] dispatchedWorkUnitIds;
    PolicyClass[] dispatchedClasses;


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


BoundedBurstEvidence
probeBoundedInteractiveBurstSustainedArrivals(
    size_t maxInteractiveBurst,
    size_t dispatchOpportunities
)
@safe
{
    BoundedBurstEvidence result;

    result.dispatchOpportunities =
        dispatchOpportunities;

    result.dispatchedWorkUnitIds =
        new size_t[dispatchOpportunities];

    result.dispatchedClasses =
        new PolicyClass[dispatchOpportunities];


    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst =
        maxInteractiveBurst;


    if (maxInteractiveBurst == 0)
    {
        result.error =
            PolicyOracleError.invalidPolicyConfiguration;

        return result;
    }


    enum size_t throughputWorkUnitId =
        size_t.max;

    size_t currentBypassRun = 0;


    foreach (
        opportunity;
        0 .. dispatchOpportunities
    )
    {
        const ReadyWork[2] ready =
        [
            ReadyWork(
                throughputWorkUnitId,
                0,
                PolicyClass.throughput,
                int.min
            ),

            ReadyWork(
                opportunity,
                opportunity + 1,
                PolicyClass.interactive,
                int.max
            )
        ];


        auto selection =
            selectBoundedInteractiveBurst(
                ready[],
                state
            );


        if (
            !selection.ok
            || !selection.hasSelection
        )
        {
            result.error =
                PolicyOracleError.internalFailure;

            return result;
        }


        result.dispatchedWorkUnitIds[
            opportunity
        ] =
            selection.stableWorkUnitId;

        result.dispatchedClasses[
            opportunity
        ] =
            selection.policyClass;


        final switch (selection.policyClass)
        {
            case PolicyClass.interactive:
                ++result.interactiveAdmissions;
                ++currentBypassRun;

                if (
                    currentBypassRun
                    > result.maxObservedThroughputBypass
                )
                {
                    result.maxObservedThroughputBypass =
                        currentBypassRun;
                }

                break;

            case PolicyClass.throughput:
                ++result.throughputAdmissions;

                currentBypassRun = 0;

                break;
        }
    }


    result.error =
        PolicyOracleError.none;

    return result;
}


/*
 * R0.4c-4 deterministic bounded-progress evidence.
 *
 * For every configured burst N:
 *
 *     maxObservedThroughputBypass <= N
 *
 * while throughput is continuously ready and a fresh interactive item is also
 * ready before every dispatch opportunity.
 */
unittest
{
    const size_t[4] bursts =
    [
        1,
        2,
        3,
        8
    ];


    foreach (burst; bursts)
    {
        const opportunities =
            (burst + 1) * 6;


        auto evidence =
            probeBoundedInteractiveBurstSustainedArrivals(
                burst,
                opportunities
            );


        assert(evidence.ok);

        assert(
            evidence.dispatchOpportunities
            == opportunities
        );


        assert(
            evidence.maxObservedThroughputBypass
            == burst
        );


        assert(
            evidence.throughputAdmissions
            == 6
        );

        assert(
            evidence.interactiveAdmissions
            == burst * 6
        );


        foreach (
            cycle;
            0 .. 6
        )
        {
            foreach (
                withinBurst;
                0 .. burst
            )
            {
                const dispatchOrdinal =
                    cycle * (burst + 1)
                    + withinBurst;


                assert(
                    evidence.dispatchedClasses[
                        dispatchOrdinal
                    ]
                    == PolicyClass.interactive
                );
            }


            const throughputOrdinal =
                cycle * (burst + 1)
                + burst;


            assert(
                evidence.dispatchedClasses[
                    throughputOrdinal
                ]
                == PolicyClass.throughput
            );
        }
    }
}


/*
 * P2 retains interactive preference when both classes are ready.
 *
 * The first admission after reset is interactive even when throughput has a
 * numerically higher priority.
 *
 * Class preference and numeric priority are therefore separate policy
 * dimensions in this candidate.
 */
unittest
{
    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst = 2;


    const ReadyWork[2] ready =
    [
        ReadyWork(
            600,
            0,
            PolicyClass.throughput,
            int.max
        ),

        ReadyWork(
            601,
            1,
            PolicyClass.interactive,
            int.min
        )
    ];


    auto selection =
        selectBoundedInteractiveBurst(
            ready[],
            state
        );


    assert(selection.ok);
    assert(selection.hasSelection);

    assert(
        selection.stableWorkUnitId
        == 601
    );

    assert(
        selection.policyClass
        == PolicyClass.interactive
    );

    assert(
        state.consecutiveInteractiveAdmissions
        == 1
    );
}


/*
 * Once the configured interactive burst is exhausted while throughput remains
 * ready, throughput must be selected even if its numeric priority is lower.
 */
unittest
{
    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst = 2;

    state.consecutiveInteractiveAdmissions = 2;


    const ReadyWork[2] ready =
    [
        ReadyWork(
            700,
            0,
            PolicyClass.throughput,
            int.min
        ),

        ReadyWork(
            701,
            1,
            PolicyClass.interactive,
            int.max
        )
    ];


    auto selection =
        selectBoundedInteractiveBurst(
            ready[],
            state
        );


    assert(selection.ok);
    assert(selection.hasSelection);

    assert(
        selection.stableWorkUnitId
        == 700
    );

    assert(
        selection.policyClass
        == PolicyClass.throughput
    );

    assert(
        state.consecutiveInteractiveAdmissions
        == 0
    );
}


/*
 * Within each selected class, P2 retains strict-priority ordering with FIFO
 * ready-order tie-breaking.
 */
unittest
{
    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst = 3;


    const ReadyWork[5] ready =
    [
        ReadyWork(
            800,
            0,
            PolicyClass.throughput,
            1000
        ),

        ReadyWork(
            801,
            1,
            PolicyClass.interactive,
            10
        ),

        ReadyWork(
            802,
            2,
            PolicyClass.interactive,
            20
        ),

        ReadyWork(
            803,
            3,
            PolicyClass.interactive,
            20
        ),

        ReadyWork(
            804,
            4,
            PolicyClass.throughput,
            2000
        )
    ];


    auto first =
        selectBoundedInteractiveBurst(
            ready[],
            state
        );


    assert(first.ok);
    assert(first.hasSelection);

    assert(
        first.stableWorkUnitId
        == 802
    );
}


/*
 * When throughput is absent, interactive admissions are not throughput bypasses
 * and therefore reset the bounded-burst counter.
 */
unittest
{
    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst = 2;
    state.consecutiveInteractiveAdmissions = 2;


    const ReadyWork[1] ready =
    [
        ReadyWork(
            900,
            0,
            PolicyClass.interactive,
            0
        )
    ];


    auto selection =
        selectBoundedInteractiveBurst(
            ready[],
            state
        );


    assert(selection.ok);
    assert(selection.hasSelection);

    assert(
        selection.policyClass
        == PolicyClass.interactive
    );

    assert(
        state.consecutiveInteractiveAdmissions
        == 0
    );
}


/*
 * Empty ready state is valid and resets burst history because no throughput
 * item remained continuously ready through the gap.
 */
unittest
{
    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst = 2;
    state.consecutiveInteractiveAdmissions = 1;


    const ReadyWork[] ready;


    auto selection =
        selectBoundedInteractiveBurst(
            ready,
            state
        );


    assert(selection.ok);
    assert(!selection.hasSelection);

    assert(
        state.consecutiveInteractiveAdmissions
        == 0
    );
}


/*
 * A zero burst is rejected because this candidate is specifically intended to
 * preserve some interactive preference while bounding throughput bypass.
 */
unittest
{
    BoundedInteractiveBurstState state;

    state.maxInteractiveBurst = 0;


    const ReadyWork[1] ready =
    [
        ReadyWork(
            1000,
            0,
            PolicyClass.throughput,
            0
        )
    ];


    auto selection =
        selectBoundedInteractiveBurst(
            ready[],
            state
        );


    assert(!selection.ok);

    assert(
        selection.error
        == PolicyOracleError.invalidPolicyConfiguration
    );


    auto evidence =
        probeBoundedInteractiveBurstSustainedArrivals(
            0,
            8
        );


    assert(!evidence.ok);

    assert(
        evidence.error
        == PolicyOracleError.invalidPolicyConfiguration
    );
}


/++
    R0.4c-5 research-local policy selector identity.

    This exists only so one termination gate can be tested against every
    candidate policy without duplicating the gate semantics.
+/
enum SchedulingPolicyKind : ubyte
{
    fifo,
    strictPriority,
    boundedInteractiveBurst
}


/++
    Request-level dispatch termination observed by orchestration.

    This is not a public cancellation/failure API.
+/
enum DispatchTermination : ubyte
{
    open,
    failed,
    cancelled
}


/++
    Minimal request-level dispatch gate.

    The first observed terminal reason is retained.
+/
struct DispatchGateState
{
    DispatchTermination termination =
        DispatchTermination.open;


    @property
    bool closed() const
    @safe
    pure
    nothrow
    @nogc
    {
        return termination
            != DispatchTermination.open;
    }


    void observeFailure()
    @safe
    pure
    nothrow
    @nogc
    {
        if (!closed)
        {
            termination =
                DispatchTermination.failed;
        }
    }


    void observeCancellation()
    @safe
    pure
    nothrow
    @nogc
    {
        if (!closed)
        {
            termination =
                DispatchTermination.cancelled;
        }
    }
}


/++
    One policy-selected admission after applying the request-level termination
    gate.
+/
struct GatedDispatchSelection
{
    PolicyOracleError error =
        PolicyOracleError.internalFailure;

    bool hasSelection;

    size_t stableWorkUnitId;


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
    Applies the request-level termination gate before consulting any scheduling
    policy.

    Important R0.4c-5 rule:

        closed dispatch
        ->
        do not call/validate policy
        ->
        no later admission

    Therefore request termination dominates:

    - FIFO ordering;
    - strict priority;
    - bounded-burst preference;
    - ready-set policy validation;
    - bounded-burst state updates.

    This is a deterministic admission oracle, not a production scheduler.
+/
GatedDispatchSelection selectWithTerminationGate(
    SchedulingPolicyKind policy,
    scope const(ReadyWork)[] ready,
    scope const(DispatchGateState) gate,
    ref BoundedInteractiveBurstState boundedBurstState
)
@safe
{
    GatedDispatchSelection result;


    /*
     * Request termination is checked before policy evaluation.
     */
    if (gate.closed)
    {
        result.error =
            PolicyOracleError.none;

        return result;
    }


    final switch (policy)
    {
        case SchedulingPolicyKind.fifo:
        {
            auto trace =
                dispatchFifo(
                    ready
                );


            if (!trace.ok)
            {
                result.error =
                    trace.error;

                return result;
            }


            if (trace.workUnitIds.length != 0)
            {
                result.hasSelection = true;

                result.stableWorkUnitId =
                    trace.workUnitIds[0];
            }


            result.error =
                PolicyOracleError.none;

            return result;
        }


        case SchedulingPolicyKind.strictPriority:
        {
            auto trace =
                dispatchStrictPriority(
                    ready
                );


            if (!trace.ok)
            {
                result.error =
                    trace.error;

                return result;
            }


            if (trace.workUnitIds.length != 0)
            {
                result.hasSelection = true;

                result.stableWorkUnitId =
                    trace.workUnitIds[0];
            }


            result.error =
                PolicyOracleError.none;

            return result;
        }


        case SchedulingPolicyKind.boundedInteractiveBurst:
        {
            auto selection =
                selectBoundedInteractiveBurst(
                    ready,
                    boundedBurstState
                );


            if (!selection.ok)
            {
                result.error =
                    selection.error;

                return result;
            }


            result.hasSelection =
                selection.hasSelection;

            if (selection.hasSelection)
            {
                result.stableWorkUnitId =
                    selection.stableWorkUnitId;
            }


            result.error =
                PolicyOracleError.none;

            return result;
        }
    }
}


/*
 * Open dispatch still allows each tested policy to select work.
 */
unittest
{
    const ReadyWork[3] ready =
    [
        ReadyWork(
            1100,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            1101,
            1,
            PolicyClass.interactive,
            100
        ),

        ReadyWork(
            1102,
            2,
            PolicyClass.throughput,
            50
        )
    ];


    foreach (
        policy;
        [
            SchedulingPolicyKind.fifo,
            SchedulingPolicyKind.strictPriority,
            SchedulingPolicyKind.boundedInteractiveBurst
        ]
    )
    {
        DispatchGateState gate;

        BoundedInteractiveBurstState burst;

        burst.maxInteractiveBurst = 2;


        auto selection =
            selectWithTerminationGate(
                policy,
                ready[],
                gate,
                burst
            );


        assert(selection.ok);
        assert(selection.hasSelection);
    }
}


/*
 * R0.4c-5 failure gate.
 *
 * After failure observation, no tested policy may admit later ready work.
 *
 * The ready set deliberately remains non-empty.
 */
unittest
{
    const ReadyWork[3] ready =
    [
        ReadyWork(
            1200,
            0,
            PolicyClass.throughput,
            int.min
        ),

        ReadyWork(
            1201,
            1,
            PolicyClass.interactive,
            int.max
        ),

        ReadyWork(
            1202,
            2,
            PolicyClass.interactive,
            int.max
        )
    ];


    foreach (
        policy;
        [
            SchedulingPolicyKind.fifo,
            SchedulingPolicyKind.strictPriority,
            SchedulingPolicyKind.boundedInteractiveBurst
        ]
    )
    {
        DispatchGateState gate;

        gate.observeFailure();


        BoundedInteractiveBurstState burst;

        burst.maxInteractiveBurst = 2;

        burst.consecutiveInteractiveAdmissions = 1;


        const beforeBurst =
            burst;


        auto selection =
            selectWithTerminationGate(
                policy,
                ready[],
                gate,
                burst
            );


        assert(selection.ok);
        assert(!selection.hasSelection);

        assert(
            gate.termination
            == DispatchTermination.failed
        );


        /*
         * Closed dispatch cannot advance fairness state.
         */
        assert(
            burst.maxInteractiveBurst
            == beforeBurst.maxInteractiveBurst
        );

        assert(
            burst.consecutiveInteractiveAdmissions
            == beforeBurst.consecutiveInteractiveAdmissions
        );
    }
}


/*
 * R0.4c-5 cancellation gate.
 *
 * Cancellation has the same admission effect as failure:
 *
 *     no later policy selection
 */
unittest
{
    const ReadyWork[2] ready =
    [
        ReadyWork(
            1300,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            1301,
            1,
            PolicyClass.interactive,
            1
        )
    ];


    foreach (
        policy;
        [
            SchedulingPolicyKind.fifo,
            SchedulingPolicyKind.strictPriority,
            SchedulingPolicyKind.boundedInteractiveBurst
        ]
    )
    {
        DispatchGateState gate;

        gate.observeCancellation();


        BoundedInteractiveBurstState burst;

        burst.maxInteractiveBurst = 3;

        burst.consecutiveInteractiveAdmissions = 2;


        const beforeBurst =
            burst;


        auto selection =
            selectWithTerminationGate(
                policy,
                ready[],
                gate,
                burst
            );


        assert(selection.ok);
        assert(!selection.hasSelection);

        assert(
            gate.termination
            == DispatchTermination.cancelled
        );


        assert(
            burst.maxInteractiveBurst
            == beforeBurst.maxInteractiveBurst
        );

        assert(
            burst.consecutiveInteractiveAdmissions
            == beforeBurst.consecutiveInteractiveAdmissions
        );
    }
}


/*
 * Termination dominates policy validation.
 *
 * Once dispatch is closed, ambiguous ready metadata is no longer consulted.
 *
 * This proves that a later policy error cannot reopen or override request
 * termination.
 */
unittest
{
    const ReadyWork[2] policyInvalidReady =
    [
        ReadyWork(
            1400,
            0,
            PolicyClass.throughput,
            0
        ),

        ReadyWork(
            1400,
            0,
            PolicyClass.interactive,
            100
        )
    ];


    foreach (
        policy;
        [
            SchedulingPolicyKind.fifo,
            SchedulingPolicyKind.strictPriority,
            SchedulingPolicyKind.boundedInteractiveBurst
        ]
    )
    {
        DispatchGateState gate;

        gate.observeFailure();


        BoundedInteractiveBurstState burst;

        /*
         * Deliberately invalid P2 configuration as well.
         *
         * Closed dispatch must still return no admission without consulting
         * the policy.
         */
        burst.maxInteractiveBurst = 0;

        burst.consecutiveInteractiveAdmissions = 77;


        auto selection =
            selectWithTerminationGate(
                policy,
                policyInvalidReady[],
                gate,
                burst
            );


        assert(selection.ok);
        assert(!selection.hasSelection);

        assert(
            burst.maxInteractiveBurst
            == 0
        );

        assert(
            burst.consecutiveInteractiveAdmissions
            == 77
        );
    }
}


/*
 * The first observed terminal reason remains stable.
 */
unittest
{
    DispatchGateState failedFirst;

    failedFirst.observeFailure();
    failedFirst.observeCancellation();

    assert(
        failedFirst.termination
        == DispatchTermination.failed
    );


    DispatchGateState cancelledFirst;

    cancelledFirst.observeCancellation();
    cancelledFirst.observeFailure();

    assert(
        cancelledFirst.termination
        == DispatchTermination.cancelled
    );
}

