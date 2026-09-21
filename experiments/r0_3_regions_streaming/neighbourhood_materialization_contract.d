module neighbourhood_materialization_contract;

import imagery.raster.region : Region2D;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import procedural_source :
    materializeProcedural,
    proceduralValue;


/++
    E3.3 semantic halo dependency.

    Kept local to the research experiment; not a production API.
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
 * A one-pixel output task derives a 3 x 3 logical dependency.
 *
 * Materialization rebases that dependency into resident descriptor space
 * without losing its logical/global source coordinates.
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

    ExpandedDependency dependency;

    assert(
        tryExpandDependency(
            logicalExtent,
            outputTask,
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

    auto source =
        materializeProcedural(
            logicalExtent,
            dependency.validInput
        );

    assert(source.ok);

    assert(
        source.materialized.logicalRequest
        == dependency.validInput
    );

    assert(
        source.materialized.residentBytes
        == 9
    );

    auto view =
        source.materialized.lease.view();

    assert(
        view.region
        == Region2D(
            0,
            0,
            3,
            3
        )
    );

    /*
     * The output center is derived from logical region geometry.
     * Do not encode "+1" as an independent coordinate convention.
     */
    const sourceBaseX =
        outputTask.x
        - dependency.validInput.x;

    const sourceBaseY =
        outputTask.y
        - dependency.validInput.y;

    assert(sourceBaseX == 1);
    assert(sourceBaseY == 1);

    ubyte sample;

    // Resident top-left -> logical dependency top-left.
    assert(
        view.trySample(
            0,
            0,
            0,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            108,
            208
        )
    );

    // Resident center -> logical output pixel.
    assert(
        view.trySample(
            0,
            sourceBaseX,
            sourceBaseY,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            outputTask.x,
            outputTask.y
        )
    );

    // Resident bottom-right -> logical dependency bottom-right.
    assert(
        view.trySample(
            0,
            2,
            2,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            110,
            210
        )
    );
}


/*
 * The same mapping holds for a multi-pixel output task.
 *
 * This proves that the one-pixel fixture above is not a special case.
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

    ExpandedDependency dependency;

    assert(
        tryExpandDependency(
            logicalExtent,
            outputTask,
            neighbourhoodMargins(),
            dependency
        )
    );

    assert(
        dependency.validInput
        == Region2D(
            1009,
            2010,
            6,
            5
        )
    );

    assert(
        dependency.contextDeficit
        == ContextDeficit.init
    );

    auto source =
        materializeProcedural(
            logicalExtent,
            dependency.validInput
        );

    assert(source.ok);

    assert(
        source.materialized.logicalRequest
        == dependency.validInput
    );

    assert(
        source.materialized.residentBytes
        == 30
    );

    auto view =
        source.materialized.lease.view();

    assert(
        view.region
        == Region2D(
            0,
            0,
            6,
            5
        )
    );

    const sourceBaseX =
        outputTask.x
        - dependency.validInput.x;

    const sourceBaseY =
        outputTask.y
        - dependency.validInput.y;

    assert(sourceBaseX == 1);
    assert(sourceBaseY == 1);

    ubyte sample;

    // Complete resident dependency top-left.
    assert(
        view.trySample(
            0,
            0,
            0,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            1009,
            2010
        )
    );

    // First output pixel center.
    assert(
        view.trySample(
            0,
            sourceBaseX,
            sourceBaseY,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            1010,
            2011
        )
    );

    /*
     * Last output pixel:
     *
     * local output = (3, 2)
     * resident source center = (4, 3)
     * logical coordinate = (1013, 2013)
     */
    assert(
        view.trySample(
            0,
            sourceBaseX + 3,
            sourceBaseY + 2,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            1013,
            2013
        )
    );

    // Complete resident dependency bottom-right.
    assert(
        view.trySample(
            0,
            5,
            4,
            sample
        )
    );

    assert(
        sample
        == proceduralValue(
            1014,
            2014
        )
    );
}
