module neighbourhood_task_execution;

import raster.region : Region2D;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import neighbourhood_kernel :
    weightedNeighbourhood3x3;

import procedural_source :
    ProceduralMaterializationError,
    materializeProcedural,
    proceduralValue;


/++
    E3.3.4 single-task execution failure category.

    This is research diagnostics, not a proposed production error hierarchy.
+/
enum NeighbourhoodTaskError : ubyte
{
    none,

    invalidOutputTask,
    dependencyDerivationFailed,
    unsatisfiedContext,

    sourceMaterializationFailed,
    sourceContractMismatch,

    sampleCountOverflow,
    sampleReadFailed,

    internalFailure
}


/++
    Result of executing the E3.3 neighbourhood kernel for one logical output
    task.

    `output` is currently an ordinary research buffer.

    E3.3.4 intentionally does not yet introduce a resident destination raster,
    decomposition or reassembly.
+/
struct NeighbourhoodTaskResult
{
    NeighbourhoodTaskError error =
        NeighbourhoodTaskError.internalFailure;

    ExpandedDependency dependency;

    ProceduralMaterializationError sourceError =
        ProceduralMaterializationError.none;

    ubyte[] output;

    size_t sourceResidentBytes;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == NeighbourhoodTaskError.none;
    }
}


/++
    Semantic dependency of the exact E3.3 3 x 3 kernel.
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


/++
    Executes the exact E3.3 3 x 3 neighbourhood kernel for one logical output
    task.

    Processing path:

        validate output task
            ->
        derive DependencyMargins(1,1,1,1)
            ->
        require ContextDeficit.init
            ->
        materialize dependency.validInput
            ->
        derive output-to-resident-source offset from logical regions
            ->
        read each 3 x 3 resident neighbourhood
            ->
        weightedNeighbourhood3x3()
            ->
        ordinary output buffer

    A logical-image boundary that cannot satisfy the required halo returns
    `unsatisfiedContext`.

    No border samples are synthesized.
+/
NeighbourhoodTaskResult executeNeighbourhoodTask(
    Region2D logicalExtent,
    Region2D outputTask
)
@safe
{
    NeighbourhoodTaskResult result;

    if (
        !outputTask.hasRepresentableExtent()
        || outputTask.empty()
    )
    {
        result.error =
            NeighbourhoodTaskError.invalidOutputTask;

        return result;
    }


    if (!tryExpandDependency(
        logicalExtent,
        outputTask,
        neighbourhoodMargins(),
        result.dependency
    ))
    {
        result.error =
            NeighbourhoodTaskError.dependencyDerivationFailed;

        return result;
    }


    if (
        result.dependency.contextDeficit
        != ContextDeficit.init
    )
    {
        result.error =
            NeighbourhoodTaskError.unsatisfiedContext;

        return result;
    }


    auto source =
        materializeProcedural(
            logicalExtent,
            result.dependency.validInput
        );

    if (!source.ok)
    {
        result.error =
            NeighbourhoodTaskError.sourceMaterializationFailed;

        result.sourceError =
            source.error;

        return result;
    }


    if (
        source.materialized.logicalRequest
        != result.dependency.validInput
    )
    {
        result.error =
            NeighbourhoodTaskError.sourceContractMismatch;

        return result;
    }


    auto sourceView =
        source.materialized.lease.view();

    const expectedResidentRegion =
        Region2D(
            0,
            0,
            result.dependency.validInput.width,
            result.dependency.validInput.height
        );

    if (
        sourceView.region
        != expectedResidentRegion
    )
    {
        result.error =
            NeighbourhoodTaskError.sourceContractMismatch;

        return result;
    }


    if (
        result.dependency.validInput.x
            > outputTask.x
        || result.dependency.validInput.y
            > outputTask.y
    )
    {
        result.error =
            NeighbourhoodTaskError.sourceContractMismatch;

        return result;
    }


    /*
     * Derive the mapping from logical region geometry.
     *
     * For the current fully satisfied one-pixel margins these offsets are
     * expected to be one, but execution does not encode "+1" as an independent
     * coordinate convention.
     */
    const sourceBaseX =
        outputTask.x
        - result.dependency.validInput.x;

    const sourceBaseY =
        outputTask.y
        - result.dependency.validInput.y;


    /*
     * Every output center requires one resident source sample on its left,
     * top, right and bottom.
     *
     * Use inequalities rather than unchecked coordinate additions.
     */
    if (
        sourceBaseX < 1
        || sourceBaseY < 1
        || sourceBaseX >= sourceView.region.width
        || sourceBaseY >= sourceView.region.height
    )
    {
        result.error =
            NeighbourhoodTaskError.sourceContractMismatch;

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
        /*
         * Strict inequality is required because one additional sample is
         * needed on the right and bottom of the final output center.
         */
        result.error =
            NeighbourhoodTaskError.sourceContractMismatch;

        return result;
    }


    if (
        outputTask.width != 0
        && outputTask.height
            > size_t.max / outputTask.width
    )
    {
        result.error =
            NeighbourhoodTaskError.sampleCountOverflow;

        return result;
    }


    const sampleCount =
        outputTask.width
        * outputTask.height;

    assert(sampleCount != 0);

    result.output =
        new ubyte[sampleCount];

    result.sourceResidentBytes =
        source.materialized.residentBytes;


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
                    NeighbourhoodTaskError.sampleReadFailed;

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
        NeighbourhoodTaskError.none;

    return result;
}


/*
 * Independent logical-coordinate oracle for task-execution tests.
 *
 * The kernel arithmetic itself is already tested separately in
 * neighbourhood_kernel.d.
 */
private ubyte expectedLogicalNeighbourhood(
    size_t logicalX,
    size_t logicalY
)
@safe
pure
nothrow
@nogc
{
    assert(logicalX != 0);
    assert(logicalY != 0);

    return weightedNeighbourhood3x3(
        proceduralValue(
            logicalX - 1,
            logicalY - 1
        ),
        proceduralValue(
            logicalX,
            logicalY - 1
        ),
        proceduralValue(
            logicalX + 1,
            logicalY - 1
        ),

        proceduralValue(
            logicalX - 1,
            logicalY
        ),
        proceduralValue(
            logicalX,
            logicalY
        ),
        proceduralValue(
            logicalX + 1,
            logicalY
        ),

        proceduralValue(
            logicalX - 1,
            logicalY + 1
        ),
        proceduralValue(
            logicalX,
            logicalY + 1
        ),
        proceduralValue(
            logicalX + 1,
            logicalY + 1
        )
    );
}


/*
 * One output pixel consumes exactly one materialized 3 x 3 dependency.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            20
        );

    const outputTask =
        Region2D(
            109,
            209,
            1,
            1
        );

    auto result =
        executeNeighbourhoodTask(
            logicalExtent,
            outputTask
        );

    assert(result.ok);

    assert(
        result.dependency.validInput
        == Region2D(
            108,
            208,
            3,
            3
        )
    );

    assert(
        result.dependency.contextDeficit
        == ContextDeficit.init
    );

    assert(result.sourceResidentBytes == 9);

    assert(result.output.length == 1);

    assert(
        result.output[0]
        == expectedLogicalNeighbourhood(
            109,
            209
        )
    );
}


/*
 * A multi-pixel output task is evaluated entirely through its materialized
 * logical halo.
 */
unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            50,
            40
        );

    const outputTask =
        Region2D(
            1010,
            2011,
            4,
            3
        );

    auto result =
        executeNeighbourhoodTask(
            logicalExtent,
            outputTask
        );

    assert(result.ok);

    assert(
        result.dependency.validInput
        == Region2D(
            1009,
            2010,
            6,
            5
        )
    );

    assert(
        result.dependency.contextDeficit
        == ContextDeficit.init
    );

    assert(result.sourceResidentBytes == 30);

    assert(
        result.output.length
        == outputTask.width
            * outputTask.height
    );

    foreach (localY; 0 .. outputTask.height)
    {
        foreach (localX; 0 .. outputTask.width)
        {
            const logicalX =
                outputTask.x
                + localX;

            const logicalY =
                outputTask.y
                + localY;

            const outputIndex =
                localY * outputTask.width
                + localX;

            assert(
                result.output[outputIndex]
                == expectedLogicalNeighbourhood(
                    logicalX,
                    logicalY
                )
            );
        }
    }
}


/*
 * Missing logical-image context is detected before materialization and kernel
 * execution.
 *
 * No border policy is silently invented.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            20
        );

    const outputTask =
        Region2D(
            100,
            200,
            1,
            1
        );

    auto result =
        executeNeighbourhoodTask(
            logicalExtent,
            outputTask
        );

    assert(!result.ok);

    assert(
        result.error
        == NeighbourhoodTaskError.unsatisfiedContext
    );

    assert(
        result.dependency.validInput
        == Region2D(
            100,
            200,
            2,
            2
        )
    );

    assert(
        result.dependency.contextDeficit
        == ContextDeficit(
            1,
            1,
            0,
            0
        )
    );

    assert(result.output.length == 0);
    assert(result.sourceResidentBytes == 0);
}
