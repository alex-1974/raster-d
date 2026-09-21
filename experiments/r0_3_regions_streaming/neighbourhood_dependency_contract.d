module neighbourhood_dependency_contract;

import raster.region : Region2D;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import region_algebra :
    tryIntersection;


/++
    Semantic dependency of the exact E3.3 3 x 3 neighbourhood kernel.

    This is deliberately kept local to the research experiment.

    It is not a proposed production API.
+/
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
 * The E3.3 principal whole-request fixture has complete one-pixel context.
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

    const output =
        Region2D(
            1733,
            911,
            1021,
            769
        );

    ExpandedDependency dependency;

    assert(
        tryExpandDependency(
            logicalExtent,
            output,
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            1732,
            910,
            1023,
            771
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit.init
    );
}


/*
 * One interior output pixel requires an exact 3 x 3 logical source region.
 */
unittest
{
    ExpandedDependency dependency;

    assert(
        tryExpandDependency(
            Region2D(
                100,
                200,
                20,
                20
            ),
            Region2D(
                109,
                209,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            108,
            208,
            3,
            3
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit.init
    );
}


/*
 * Each logical-image edge reports only its unavailable one-pixel context.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            10
        );

    ExpandedDependency dependency;

    // Left.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                100,
                204,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            100,
            203,
            2,
            3
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            1,
            0,
            0,
            0
        )
    );

    // Top.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                109,
                200,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            108,
            200,
            3,
            2
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            0,
            1,
            0,
            0
        )
    );

    // Right.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                119,
                204,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            118,
            203,
            2,
            3
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            0,
            0,
            1,
            0
        )
    );

    // Bottom.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                109,
                209,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            108,
            208,
            3,
            2
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            0,
            0,
            0,
            1
        )
    );
}


/*
 * Logical-image corners report the corresponding two-axis context deficit.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            10
        );

    ExpandedDependency dependency;

    // Top-left.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                100,
                200,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            100,
            200,
            2,
            2
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            1,
            1,
            0,
            0
        )
    );

    // Top-right.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                119,
                200,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            118,
            200,
            2,
            2
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            0,
            1,
            1,
            0
        )
    );

    // Bottom-left.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                100,
                209,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            100,
            208,
            2,
            2
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            1,
            0,
            0,
            1
        )
    );

    // Bottom-right.
    assert(
        tryExpandDependency(
            logicalExtent,
            Region2D(
                119,
                209,
                1,
                1
            ),
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            118,
            208,
            2,
            2
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit(
            0,
            0,
            1,
            1
        )
    );
}


/*
 * An internal processing-task boundary is not a logical-image boundary.
 *
 * Adjacent output tasks receive complete context with no deficit.
 *
 * Their input dependencies overlap because both tasks require neighbourhood
 * samples around the shared processing boundary.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            100,
            100
        );

    const leftTask =
        Region2D(
            20,
            30,
            10,
            10
        );

    const rightTask =
        Region2D(
            30,
            30,
            10,
            10
        );

    ExpandedDependency leftDependency;
    ExpandedDependency rightDependency;

    assert(
        tryExpandDependency(
            logicalExtent,
            leftTask,
            neighbourhoodMargins(),
            leftDependency
        )
    );

    assert(
        tryExpandDependency(
            logicalExtent,
            rightTask,
            neighbourhoodMargins(),
            rightDependency
        )
    );

    assert(
        leftDependency.validInput
        == Region2D(
            19,
            29,
            12,
            12
        )
    );

    assert(
        rightDependency.validInput
        == Region2D(
            29,
            29,
            12,
            12
        )
    );

    assert(
        leftDependency.contextDeficit
        == ContextDeficit.init
    );

    assert(
        rightDependency.contextDeficit
        == ContextDeficit.init
    );

    Region2D overlap;

    assert(
        tryIntersection(
            leftDependency.validInput,
            rightDependency.validInput,
            overlap
        )
    );

    assert(
        overlap
        == Region2D(
            29,
            29,
            2,
            12
        )
    );
}
