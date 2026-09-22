module dependency;

import raster.region : Region2D;
import region_algebra : tryContainsAbsolute;


/++
    Required rectangular context around an output request.

    These values describe semantic input dependency, not provider overlap,
    cache padding or border handling.
+/
struct DependencyMargins
{
    size_t left;
    size_t top;
    size_t right;
    size_t bottom;
}


/++
    Required dependency context that lies outside the valid logical extent.

    This carries information only. It does not select a border policy.
+/
struct ContextDeficit
{
    size_t left;
    size_t top;
    size_t right;
    size_t bottom;
}


/++
    Result of deriving a request-bounded rectangular dependency.

    `validInput` is the portion of required input that lies inside the logical
    extent.

    `contextDeficit` records context required beyond that extent.
+/
struct ExpandedDependency
{
    Region2D validInput;
    ContextDeficit contextDeficit;
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
    Derives the valid input and outside-extent context deficit for a rectangular
    request-bounded dependency.

    Returns false when:

    - `logicalExtent` is unrepresentable;
    - `outputRequest` is unrepresentable;
    - `outputRequest` is not contained in `logicalExtent`.

    The operation never clips an invalid output request into the logical
    extent.

    For an empty output request, the successful result is:

        validInput =
            Region2D(outputRequest.x, outputRequest.y, 0, 0)

        contextDeficit =
            ContextDeficit.init

    regardless of the requested margins.
+/
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

    /*
     * All end-coordinate additions below are safe because absolute
     * containment has already established representable input geometry.
     */
    const logicalRight =
        logicalExtent.x + logicalExtent.width;

    const logicalBottom =
        logicalExtent.y + logicalExtent.height;

    const outputRight =
        outputRequest.x + outputRequest.width;

    const outputBottom =
        outputRequest.y + outputRequest.height;

    /*
     * Containment guarantees these subtractions cannot underflow.
     */
    const availableLeft =
        outputRequest.x - logicalExtent.x;

    const availableTop =
        outputRequest.y - logicalExtent.y;

    const availableRight =
        logicalRight - outputRight;

    const availableBottom =
        logicalBottom - outputBottom;

    const usedLeft =
        lesser(margins.left, availableLeft);

    const usedTop =
        lesser(margins.top, availableTop);

    const usedRight =
        lesser(margins.right, availableRight);

    const usedBottom =
        lesser(margins.bottom, availableBottom);

    const validX =
        outputRequest.x - usedLeft;

    const validY =
        outputRequest.y - usedTop;

    /*
     * Because usedRight/usedBottom cannot exceed the available space,
     * these additions cannot exceed logicalRight/logicalBottom.
     */
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


/*
 * Zero margins preserve the output request exactly.
 */
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


/*
 * A centered request can satisfy all requested context.
 */
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


/*
 * Logical extents with non-zero origins are handled by absolute coordinates.
 */
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


/*
 * Each logical edge produces only the corresponding deficit.
 */
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

    assert(result.validInput ==
        Region2D(16, 0, 20, 17));

    assert(result.contextDeficit ==
        ContextDeficit(0, 5, 0, 0));


    assert(tryExpandDependency(
        logical,
        Region2D(90, 20, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(86, 15, 14, 22));

    assert(result.contextDeficit ==
        ContextDeficit(0, 0, 6, 0));


    assert(tryExpandDependency(
        logical,
        Region2D(20, 70, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(16, 65, 20, 15));

    assert(result.contextDeficit ==
        ContextDeficit(0, 0, 0, 7));
}


/*
 * Corner requests may have deficits on two axes simultaneously.
 */
unittest
{
    ExpandedDependency result;

    const margins =
        DependencyMargins(
            3,
            4,
            5,
            6
        );

    assert(tryExpandDependency(
        Region2D(0, 0, 100, 80),
        Region2D(0, 0, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(0, 0, 15, 16));

    assert(result.contextDeficit ==
        ContextDeficit(3, 4, 0, 0));


    assert(tryExpandDependency(
        Region2D(0, 0, 100, 80),
        Region2D(90, 70, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(87, 66, 13, 14));

    assert(result.contextDeficit ==
        ContextDeficit(0, 0, 5, 6));
}


/*
 * The remaining two corners exercise the opposite combinations of horizontal
 * and vertical context deficit.
 */
unittest
{
    ExpandedDependency result;

    const logical =
        Region2D(0, 0, 100, 80);

    const margins =
        DependencyMargins(
            3,
            4,
            5,
            6
        );

    assert(tryExpandDependency(
        logical,
        Region2D(90, 0, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(87, 0, 13, 16));

    assert(result.contextDeficit ==
        ContextDeficit(0, 4, 5, 0));


    assert(tryExpandDependency(
        logical,
        Region2D(0, 70, 10, 10),
        margins,
        result
    ));

    assert(result.validInput ==
        Region2D(0, 66, 15, 14));

    assert(result.contextDeficit ==
        ContextDeficit(3, 0, 0, 6));
}


/*
 * An empty logical extent can contain the equally anchored empty output.
 * Dependency derivation remains a successful empty result with no deficit.
 */
unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(100, 200, 0, 0),
        Region2D(100, 200, 0, 0),
        DependencyMargins(
            size_t.max,
            size_t.max,
            size_t.max,
            size_t.max
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(100, 200, 0, 0));

    assert(result.contextDeficit ==
        ContextDeficit.init);
}


/*
 * Whole-extent output cannot obtain any outside context from the logical
 * image itself.
 */
unittest
{
    const logical =
        Region2D(100, 200, 30, 40);

    const margins =
        DependencyMargins(
            1,
            2,
            3,
            4
        );

    ExpandedDependency result;

    assert(tryExpandDependency(
        logical,
        logical,
        margins,
        result
    ));

    assert(result.validInput == logical);

    assert(result.contextDeficit ==
        ContextDeficit(
            1,
            2,
            3,
            4
        ));
}


/*
 * Margins may be substantially larger than both output and logical extents.
 */
unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(100, 200, 30, 40),
        Region2D(110, 210, 5, 5),
        DependencyMargins(
            1000,
            2000,
            3000,
            4000
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(100, 200, 30, 40));

    assert(result.contextDeficit ==
        ContextDeficit(
            990,
            1990,
            2985,
            3975
        ));
}


/*
 * size_t.max margins remain valid input and do not require overflowing
 * expanded coordinates.
 */
unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(10, 20, 30, 40),
        Region2D(15, 25, 10, 10),
        DependencyMargins(
            size_t.max,
            size_t.max,
            size_t.max,
            size_t.max
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(10, 20, 30, 40));

    assert(result.contextDeficit ==
        ContextDeficit(
            size_t.max - 5,
            size_t.max - 5,
            size_t.max - 15,
            size_t.max - 25
        ));
}


/*
 * Geometry at the maximum representable end remains safe.
 */
unittest
{
    ExpandedDependency result;

    const logical =
        Region2D(
            size_t.max - 100,
            size_t.max - 80,
            100,
            80
        );

    const output =
        Region2D(
            size_t.max - 60,
            size_t.max - 50,
            20,
            20
        );

    assert(logical.hasRepresentableExtent());
    assert(output.hasRepresentableExtent());

    assert(tryExpandDependency(
        logical,
        output,
        DependencyMargins(
            50,
            50,
            50,
            50
        ),
        result
    ));

    assert(result.validInput == logical);

    assert(result.contextDeficit ==
        ContextDeficit(
            10,
            20,
            10,
            20
        ));
}


/*
 * Empty output requires no input context, regardless of margins.
 */
unittest
{
    ExpandedDependency result;

    assert(tryExpandDependency(
        Region2D(100, 200, 30, 40),
        Region2D(110, 220, 0, 10),
        DependencyMargins(
            size_t.max,
            size_t.max,
            size_t.max,
            size_t.max
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(110, 220, 0, 0));

    assert(result.contextDeficit ==
        ContextDeficit.init);


    assert(tryExpandDependency(
        Region2D(100, 200, 30, 40),
        Region2D(130, 240, 0, 0),
        DependencyMargins(
            1,
            2,
            3,
            4
        ),
        result
    ));

    assert(result.validInput ==
        Region2D(130, 240, 0, 0));

    assert(result.contextDeficit ==
        ContextDeficit.init);
}


/*
 * An output request outside the logical extent is invalid for this operation;
 * it is never silently clipped.
 */
unittest
{
    ExpandedDependency result =
        ExpandedDependency(
            Region2D(1, 2, 3, 4),
            ContextDeficit(5, 6, 7, 8)
        );

    assert(!tryExpandDependency(
        Region2D(10, 20, 30, 40),
        Region2D(9, 20, 10, 10),
        DependencyMargins.init,
        result
    ));

    assert(result == ExpandedDependency.init);


    result =
        ExpandedDependency(
            Region2D(1, 2, 3, 4),
            ContextDeficit(5, 6, 7, 8)
        );

    assert(!tryExpandDependency(
        Region2D(10, 20, 30, 40),
        Region2D(40, 20, 1, 1),
        DependencyMargins.init,
        result
    ));

    assert(result == ExpandedDependency.init);
}


/*
 * Unrepresentable input geometry fails before dependency arithmetic.
 */
unittest
{
    const invalid =
        Region2D(
            size_t.max,
            0,
            1,
            1
        );

    ExpandedDependency result =
        ExpandedDependency(
            Region2D(1, 2, 3, 4),
            ContextDeficit(5, 6, 7, 8)
        );

    assert(!tryExpandDependency(
        invalid,
        Region2D.init,
        DependencyMargins.init,
        result
    ));

    assert(result == ExpandedDependency.init);


    result =
        ExpandedDependency(
            Region2D(1, 2, 3, 4),
            ContextDeficit(5, 6, 7, 8)
        );

    assert(!tryExpandDependency(
        Region2D(
            0,
            0,
            size_t.max,
            size_t.max
        ),
        invalid,
        DependencyMargins.init,
        result
    ));

    assert(result == ExpandedDependency.init);
}
