module reuse_probe;

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
    proceduralValue;

import neighbourhood_kernel :
    weightedNeighbourhood3x3;

import neighbourhood_task_execution :
    executeNeighbourhoodTask;


/*
 * R0.4a sibling-research-module reuse probe.
 *
 * This is not the R0.4a executor.
 *
 * It proves only that the selected immutable R0.3 research modules can be
 * consumed together from the R0.4a DUB package without copying their
 * implementations or modifying the historical R0.3 experiment.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            32,
            32
        );

    const outputTask =
        Region2D(
            110,
            210,
            1,
            1
        );


    ExpandedDependency dependency;

    assert(
        tryExpandDependency(
            logicalExtent,
            outputTask,
            DependencyMargins(
                1,
                1,
                1,
                1
            ),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            109,
            209,
            3,
            3
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit.init
    );


    bool contained;

    assert(
        tryContainsAbsolute(
            logicalExtent,
            dependency.validInput,
            contained
        )
    );

    assert(contained);


    const Region2D[1] decomposition =
    [
        outputTask
    ];

    DecompositionIssue decompositionIssue;

    assert(
        tryValidateDecomposition(
            outputTask,
            decomposition[],
            decompositionIssue
        )
    );

    assert(
        decompositionIssue
        == DecompositionIssue.none
    );


    const expected =
        weightedNeighbourhood3x3(
            proceduralValue(109, 209),
            proceduralValue(110, 209),
            proceduralValue(111, 209),

            proceduralValue(109, 210),
            proceduralValue(110, 210),
            proceduralValue(111, 210),

            proceduralValue(109, 211),
            proceduralValue(110, 211),
            proceduralValue(111, 211)
        );


    auto oracle =
        executeNeighbourhoodTask(
            logicalExtent,
            outputTask
        );

    assert(oracle.ok);
    assert(oracle.output.length == 1);
    assert(oracle.output[0] == expected);
}
