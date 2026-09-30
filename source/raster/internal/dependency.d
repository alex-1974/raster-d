module raster.internal.dependency;

import raster.region : Region2D;


/++
    Rectangular context required around a logical output request.

    This is dependency geometry only. It does not encode border policy,
    provider overlap, cache padding or scheduler behaviour.
+/
package(raster)
struct DependencyMargins
{
    size_t left;
    size_t top;
    size_t right;
    size_t bottom;
}


/++
    Required dependency context that lies outside the valid logical extent.

    A non-zero deficit records unsatisfied logical context. It does not select
    or imply any border-synthesis policy.
+/
package(raster)
struct ContextDeficit
{
    size_t left;
    size_t top;
    size_t right;
    size_t bottom;
}


/++
    Result of deriving a request-bounded rectangular dependency.

    validInput is the portion of the mathematical dependency that lies inside
    the logical extent.

    contextDeficit records required context beyond that extent.
+/
package(raster)
struct ExpandedDependency
{
    Region2D validInput;
    ContextDeficit contextDeficit;
}


private bool tryContainsAbsolute(
    Region2D outer,
    Region2D inner,
    out bool contains
)
@safe
pure
nothrow
@nogc
{
    contains = false;

    if (!outer.hasRepresentableExtent()
        || !inner.hasRepresentableExtent())
    {
        return false;
    }

    const outerRight =
        outer.x + outer.width;

    const outerBottom =
        outer.y + outer.height;

    const innerRight =
        inner.x + inner.width;

    const innerBottom =
        inner.y + inner.height;

    contains =
        inner.x >= outer.x
        && inner.y >= outer.y
        && innerRight <= outerRight
        && innerBottom <= outerBottom;

    return true;
}


private size_t lesser(
    size_t a,
    size_t b
)
@safe
pure
nothrow
@nogc
{
    return a <= b
        ? a
        : b;
}


/++
    Derives the valid logical input and directional outside-extent context
    deficit for a request-bounded rectangular dependency.

    Failure means that logicalExtent or outputRequest is unrepresentable, or
    that outputRequest is not contained in logicalExtent.

    Failure resets result to ExpandedDependency.init.

    Empty output requests are valid. They preserve their logical anchor as an
    empty validInput and produce zero context deficit regardless of margins.
+/
package(raster)
bool tryExpandDependency(
    Region2D logicalExtent,
    Region2D outputRequest,
    DependencyMargins margins,
    out ExpandedDependency result
)
@safe
pure
nothrow
@nogc
{
    result = ExpandedDependency.init;

    bool contained;

    if (!tryContainsAbsolute(
        logicalExtent,
        outputRequest,
        contained
    ))
    {
        return false;
    }

    if (!contained)
    {
        return false;
    }

    if (outputRequest.empty())
    {
        result.validInput =
            Region2D(
                outputRequest.x,
                outputRequest.y,
                0,
                0
            );

        return true;
    }

    const logicalRight =
        logicalExtent.x + logicalExtent.width;

    const logicalBottom =
        logicalExtent.y + logicalExtent.height;

    const outputRight =
        outputRequest.x + outputRequest.width;

    const outputBottom =
        outputRequest.y + outputRequest.height;

    const availableLeft =
        outputRequest.x - logicalExtent.x;

    const availableTop =
        outputRequest.y - logicalExtent.y;

    const availableRight =
        logicalRight - outputRight;

    const availableBottom =
        logicalBottom - outputBottom;

    const usedLeft =
        lesser(
            margins.left,
            availableLeft
        );

    const usedTop =
        lesser(
            margins.top,
            availableTop
        );

    const usedRight =
        lesser(
            margins.right,
            availableRight
        );

    const usedBottom =
        lesser(
            margins.bottom,
            availableBottom
        );

    const validX =
        outputRequest.x - usedLeft;

    const validY =
        outputRequest.y - usedTop;

    const validRight =
        outputRight + usedRight;

    const validBottom =
        outputBottom + usedBottom;

    result.validInput =
        Region2D(
            validX,
            validY,
            validRight - validX,
            validBottom - validY
        );

    result.contextDeficit =
        ContextDeficit(
            margins.left - usedLeft,
            margins.top - usedTop,
            margins.right - usedRight,
            margins.bottom - usedBottom
        );

    return true;
}


unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(0, 0, 100, 80),
        Region2D(20, 30, 10, 15),
        DependencyMargins.init,
        result
    ));

    assert(result.validInput ==
        Region2D(20, 30, 10, 15));

    assert(result.contextDeficit ==
        ContextDeficit.init);
}


unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(0, 0, 100, 80),
        Region2D(20, 30, 10, 15),
        DependencyMargins(
            5,
            7,
            11,
            13
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(
            15,
            23,
            26,
            35
        ));

    assert(result.contextDeficit ==
        ContextDeficit.init);
}


unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(100, 200, 300, 400),
        Region2D(120, 230, 50, 60),
        DependencyMargins(
            10,
            20,
            30,
            40
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(
            110,
            210,
            90,
            120
        ));

    assert(result.contextDeficit ==
        ContextDeficit.init);
}


unittest
{
    const logical =
        Region2D(0, 0, 100, 80);

    const margins =
        DependencyMargins(
            4,
            5,
            6,
            7
        );

    ExpandedDependency result;

    assert(tryExpandDependency(
        logical,
        Region2D(0, 20, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(0, 15, 16, 22));

    assert(result.contextDeficit ==
        ContextDeficit(4, 0, 0, 0));

    assert(tryExpandDependency(
        logical,
        Region2D(20, 0, 10, 10),
        margins,
        result
    ));

    assert(result.contextDeficit ==
        ContextDeficit(0, 5, 0, 0));

    assert(tryExpandDependency(
        logical,
        Region2D(90, 20, 10, 10),
        margins,
        result
    ));

    assert(result.contextDeficit ==
        ContextDeficit(0, 0, 6, 0));

    assert(tryExpandDependency(
        logical,
        Region2D(20, 70, 10, 10),
        margins,
        result
    ));

    assert(result.contextDeficit ==
        ContextDeficit(0, 0, 0, 7));
}


unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(10, 20, 30, 40),
        Region2D(40, 60, 0, 0),
        DependencyMargins(
            size_t.max,
            size_t.max,
            size_t.max,
            size_t.max
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(40, 60, 0, 0));

    assert(result.contextDeficit ==
        ContextDeficit.init);
}


unittest
{
    const logical =
        Region2D(
            size_t.max - 20,
            size_t.max - 30,
            20,
            30
        );

    const output =
        Region2D(
            size_t.max - 10,
            size_t.max - 15,
            10,
            15
        );

    ExpandedDependency result;

    assert(logical.hasRepresentableExtent());
    assert(output.hasRepresentableExtent());

    assert(tryExpandDependency(
        logical,
        output,
        DependencyMargins(
            10,
            15,
            0,
            0
        ),
        result
    ));

    assert(result.validInput == logical);
    assert(result.contextDeficit ==
        ContextDeficit.init);
}


unittest
{
    ExpandedDependency result =
        ExpandedDependency(
            Region2D(1, 2, 3, 4),
            ContextDeficit(1, 1, 1, 1)
        );

    assert(!tryExpandDependency(
        Region2D(
            size_t.max,
            0,
            1,
            1
        ),
        Region2D.init,
        DependencyMargins.init,
        result
    ));

    assert(result == ExpandedDependency.init);
}


unittest
{
    ExpandedDependency result =
        ExpandedDependency(
            Region2D(1, 2, 3, 4),
            ContextDeficit(1, 1, 1, 1)
        );

    assert(!tryExpandDependency(
        Region2D(0, 0, 10, 10),
        Region2D(9, 9, 2, 2),
        DependencyMargins.init,
        result
    ));

    assert(result == ExpandedDependency.init);
}
