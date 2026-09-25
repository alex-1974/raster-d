module pipeline_raster_fixture;

import raster.region :
    Region2D;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import procedural_source :
    MaterializedUbyteRaster,
    ProceduralMaterializationResult,
    materializeProcedural;

import neighbourhood_kernel :
    weightedNeighbourhood3x3;


/*
 * Shared R0.4d research fixture for real staged raster work.
 *
 * This module exists only to prevent R0.4d-2/R0.4d-4/R0.4d-5/R0.4d-6 from
 * copying the same logical-to-resident mapping and retained-source mechanics.
 *
 * It is experiment-local and is not a production API.
 */

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
 * Experiment-local resident compute orchestration.
 *
 * R0.4a/R0.4b keep equivalent orchestration private to their historical
 * modules. R0.4d therefore reconstructs only the logical-to-resident mapping
 * needed to execute the already-established public weighted kernel against an
 * already materialized source.
 *
 * This is not a production primitive.
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
        dependency.validInput.x > outputTask.x
        || dependency.validInput.y > outputTask.y
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
 * One research-local work fixture.
 *
 * The materialized source is retained explicitly across the handoff into the
 * compute stage.
 */
class PipelineRasterFixture
{
    Region2D logicalExtent;
    Region2D outputTask;

    ExpandedDependency dependency;

    ProceduralMaterializationResult sourceResult;

    ubyte[] output;

    bool dependencyReady;
    bool materializationCompleted;
    bool computeCompleted;


    this(
        Region2D logicalExtent,
        Region2D outputTask
    )
    {
        this.logicalExtent =
            logicalExtent;

        this.outputTask =
            outputTask;
    }


    bool prepareDependency()
    {
        if (
            !outputTask.hasRepresentableExtent()
            || outputTask.empty()
        )
        {
            return false;
        }


        if (!tryExpandDependency(
            logicalExtent,
            outputTask,
            neighbourhoodMargins(),
            dependency
        ))
        {
            return false;
        }


        if (
            dependency.contextDeficit
            != ContextDeficit.init
        )
        {
            return false;
        }


        dependencyReady = true;

        return true;
    }


    void materialize()
    {
        if (!dependencyReady)
        {
            return;
        }


        sourceResult =
            materializeProcedural(
                logicalExtent,
                dependency.validInput
            );


        materializationCompleted =
            sourceResult.ok;
    }


    void compute()
    {
        if (
            !materializationCompleted
            || !sourceResult.ok
        )
        {
            return;
        }


        computeCompleted =
            tryExecuteResidentNeighbourhood(
                outputTask,
                dependency,
                sourceResult.materialized,
                output
            );
    }


    @property
    size_t residentBytes() const
    {
        if (!sourceResult.ok)
        {
            return 0;
        }


        return sourceResult.materialized.residentBytes;
    }


    void releaseResident()
    {
        sourceResult =
            ProceduralMaterializationResult.init;
    }
}



bool tryCommitTaskOutput(
    Region2D requestedOutput,
    Region2D outputTask,
    scope const(ubyte)[] taskOutput,
    ref ubyte[] completeOutput,
    ref ubyte[] completedCoverage
)
@safe
{
    if (
        outputTask.x < requestedOutput.x
        || outputTask.y < requestedOutput.y
    )
    {
        return false;
    }


    if (
        taskOutput.length
        != outputTask.width * outputTask.height
    )
    {
        return false;
    }


    const baseX =
        outputTask.x
        - requestedOutput.x;

    const baseY =
        outputTask.y
        - requestedOutput.y;


    foreach (localY; 0 .. outputTask.height)
    {
        foreach (localX; 0 .. outputTask.width)
        {
            const requestedX =
                baseX + localX;

            const requestedY =
                baseY + localY;


            if (
                requestedX >= requestedOutput.width
                || requestedY >= requestedOutput.height
            )
            {
                return false;
            }


            const taskIndex =
                localY * outputTask.width
                + localX;

            const completeIndex =
                requestedY * requestedOutput.width
                + requestedX;


            if (
                completeIndex >= completeOutput.length
                || completeIndex >= completedCoverage.length
                || completedCoverage[completeIndex] != 0
            )
            {
                return false;
            }


            completeOutput[completeIndex] =
                taskOutput[taskIndex];

            completedCoverage[completeIndex] = 1;
        }
    }


    return true;
}



