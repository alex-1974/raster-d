module raster.internal.materialization_plan;

import raster.internal.dependency :
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import raster.region :
    Region2D;


/++
    Metadata-only plan mapping one logical request dependency into resident
    descriptor space.

    The plan owns no storage and performs no allocation.

    dependency remains in logical/global coordinates.

    residentInput describes the resident descriptor-space extent expected for
    materialized dependency.validInput and is rebased to (0, 0).

    residentOutput locates the requested logical output inside residentInput.
+/
package(raster)
struct RequestMaterializationPlan
{
    ExpandedDependency dependency;

    Region2D residentInput;

    Region2D residentOutput;
}


/++
    Derives request-bounded dependency geometry and rebases its valid input
    into resident descriptor space.

    Failure means dependency derivation failed.

    On success:

        plan.dependency.validInput
            remains in logical/global coordinates;

        plan.residentInput
            == Region2D(
                0,
                0,
                validInput.width,
                validInput.height
            );

        plan.residentOutput
            locates outputRequest inside residentInput.

    The output offset is derived from logical region differences, not from the
    requested margins.

    Failure resets plan to RequestMaterializationPlan.init.
+/
package(raster)
bool tryPlanRequestMaterialization(
    Region2D logicalExtent,
    Region2D outputRequest,
    DependencyMargins margins,
    out RequestMaterializationPlan plan
)
@safe
pure
nothrow
@nogc
{
    plan = RequestMaterializationPlan.init;

    ExpandedDependency dependency;

    if (!tryExpandDependency(
        logicalExtent,
        outputRequest,
        margins,
        dependency
    ))
    {
        return false;
    }

    /*
     * tryExpandDependency guarantees that outputRequest is contained in
     * dependency.validInput. Therefore these subtractions cannot underflow.
     */
    const residentOutputX =
        outputRequest.x - dependency.validInput.x;

    const residentOutputY =
        outputRequest.y - dependency.validInput.y;

    plan = RequestMaterializationPlan(
        dependency,
        Region2D(
            0,
            0,
            dependency.validInput.width,
            dependency.validInput.height
        ),
        Region2D(
            residentOutputX,
            residentOutputY,
            outputRequest.width,
            outputRequest.height
        )
    );

    return true;
}


unittest
{
    RequestMaterializationPlan plan;

    assert(tryPlanRequestMaterialization(
        Region2D(1000, 2000, 50, 40),
        Region2D(1010, 2011, 4, 3),
        DependencyMargins(1, 1, 1, 1),
        plan
    ));

    assert(
        plan.dependency.validInput
        == Region2D(1009, 2010, 6, 5)
    );

    assert(
        plan.residentInput
        == Region2D(0, 0, 6, 5)
    );

    assert(
        plan.residentOutput
        == Region2D(1, 1, 4, 3)
    );
}


unittest
{
    /*
     * Output placement is derived from actual clipped dependency geometry,
     * not blindly from the configured margins.
     */
    RequestMaterializationPlan plan;

    assert(tryPlanRequestMaterialization(
        Region2D(100, 200, 20, 20),
        Region2D(100, 205, 4, 3),
        DependencyMargins(9, 2, 1, 1),
        plan
    ));

    assert(
        plan.dependency.validInput
        == Region2D(100, 203, 5, 6)
    );

    assert(plan.dependency.contextDeficit.left == 9);

    assert(
        plan.residentInput
        == Region2D(0, 0, 5, 6)
    );

    assert(
        plan.residentOutput
        == Region2D(0, 2, 4, 3)
    );
}


unittest
{
    /*
     * Very large logical coordinates disappear from resident descriptor
     * geometry after rebasing.
     */
    const logical =
        Region2D(
            size_t.max - 100,
            size_t.max - 200,
            100,
            200
        );

    const output =
        Region2D(
            size_t.max - 70,
            size_t.max - 150,
            20,
            30
        );

    RequestMaterializationPlan plan;

    assert(tryPlanRequestMaterialization(
        logical,
        output,
        DependencyMargins(5, 7, 11, 13),
        plan
    ));

    assert(
        plan.residentInput.x == 0
        && plan.residentInput.y == 0
    );

    assert(
        plan.residentInput
        == Region2D(0, 0, 36, 50)
    );

    assert(
        plan.residentOutput
        == Region2D(5, 7, 20, 30)
    );
}


unittest
{
    /*
     * Empty logical output remains a successful empty resident plan.
     */
    RequestMaterializationPlan plan;

    assert(tryPlanRequestMaterialization(
        Region2D(10, 20, 30, 40),
        Region2D(40, 60, 0, 0),
        DependencyMargins(
            size_t.max,
            size_t.max,
            size_t.max,
            size_t.max
        ),
        plan
    ));

    assert(
        plan.dependency.validInput
        == Region2D(40, 60, 0, 0)
    );

    assert(
        plan.residentInput
        == Region2D(0, 0, 0, 0)
    );

    assert(
        plan.residentOutput
        == Region2D(0, 0, 0, 0)
    );
}


unittest
{
    /*
     * Invalid requests fail atomically.
     */
    RequestMaterializationPlan plan =
        RequestMaterializationPlan(
            ExpandedDependency.init,
            Region2D(1, 2, 3, 4),
            Region2D(5, 6, 7, 8)
        );

    assert(!tryPlanRequestMaterialization(
        Region2D(0, 0, 10, 10),
        Region2D(9, 9, 2, 2),
        DependencyMargins.init,
        plan
    ));

    assert(plan == RequestMaterializationPlan.init);
}
