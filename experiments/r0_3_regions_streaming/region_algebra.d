module region_algebra;

import imagery.raster.region : Region2D;


/++
    Direction of one experimental translation-axis delta.

    A zero-magnitude delta has no directional significance.
+/
enum AxisDirection : ubyte
{
    negative,
    positive
}


/++
    Full-size unsigned magnitude plus direction.

    This avoids narrowing translation magnitudes to a signed integer type whose
    positive range may be smaller than size_t.
+/
struct AxisDelta
{
    AxisDirection direction;
    size_t magnitude;
}


/++
    Two-dimensional experimental translation.
+/
struct Translation2D
{
    AxisDelta x;
    AxisDelta y;
}


/++
    Tests absolute containment between two regions in the same coordinate
    space.

    Returns false only when either region has an unrepresentable extent.

    A successful false `contains` result means that both geometries are valid
    but `inner` is not contained in `outer`.
+/
bool tryContainsAbsolute(
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


/++
    Computes the half-open intersection of two regions.

    Returns false only when either input has an unrepresentable extent.

    Disjoint or merely edge-touching inputs successfully produce a valid empty
    region. Empty intersections retain the independently computed intersection
    origin rather than being canonicalized to Region2D.init.
+/
bool tryIntersection(
    Region2D a,
    Region2D b,
    out Region2D result
)
@safe
pure
nothrow
@nogc
{
    result = Region2D.init;

    if (!a.hasRepresentableExtent()
        || !b.hasRepresentableExtent())
    {
        return false;
    }

    const aRight =
        a.x + a.width;

    const aBottom =
        a.y + a.height;

    const bRight =
        b.x + b.width;

    const bBottom =
        b.y + b.height;

    const startX =
        a.x >= b.x
        ? a.x
        : b.x;

    const startY =
        a.y >= b.y
        ? a.y
        : b.y;

    const endX =
        aRight <= bRight
        ? aRight
        : bRight;

    const endY =
        aBottom <= bBottom
        ? aBottom
        : bBottom;

    const width =
        endX > startX
        ? endX - startX
        : 0;

    const height =
        endY > startY
        ? endY - startY
        : 0;

    result = Region2D(
        startX,
        startY,
        width,
        height
    );

    return true;
}


private bool tryTranslateAxis(
    size_t start,
    size_t extent,
    AxisDelta delta,
    out size_t translatedStart
)
@safe
pure
nothrow
@nogc
{
    translatedStart = 0;

    if (delta.magnitude == 0)
    {
        translatedStart = start;
        return true;
    }

    final switch (delta.direction)
    {
        case AxisDirection.negative:
        {
            if (delta.magnitude > start)
            {
                return false;
            }

            translatedStart =
                start - delta.magnitude;

            return true;
        }

        case AxisDirection.positive:
        {
            /*
             * The caller has already proved that start + extent is
             * representable.
             */
            const end =
                start + extent;

            if (delta.magnitude > size_t.max - end)
            {
                return false;
            }

            translatedStart =
                start + delta.magnitude;

            return true;
        }
    }
}


/++
    Translates a representable region without clipping or saturation.

    Width and height remain unchanged.

    Failure resets `result` to Region2D.init; callers must use the boolean
    result and must not interpret Region2D.init itself as a failure sentinel.
+/
bool tryTranslate(
    Region2D source,
    Translation2D translation,
    out Region2D result
)
@safe
pure
nothrow
@nogc
{
    result = Region2D.init;

    if (!source.hasRepresentableExtent())
    {
        return false;
    }

    size_t translatedX;
    size_t translatedY;

    if (!tryTranslateAxis(
        source.x,
        source.width,
        translation.x,
        translatedX
    ))
    {
        return false;
    }

    if (!tryTranslateAxis(
        source.y,
        source.height,
        translation.y,
        translatedY
    ))
    {
        return false;
    }

    result = Region2D(
        translatedX,
        translatedY,
        source.width,
        source.height
    );

    return true;
}


private AxisDelta negative(size_t magnitude)
@safe
pure
nothrow
@nogc
{
    return AxisDelta(
        AxisDirection.negative,
        magnitude
    );
}


private AxisDelta positive(size_t magnitude)
@safe
pure
nothrow
@nogc
{
    return AxisDelta(
        AxisDirection.positive,
        magnitude
    );
}


/*
 * Absolute containment.
 */
unittest
{
    const outer =
        Region2D(10, 20, 30, 40);

    bool contains;

    assert(tryContainsAbsolute(
        outer,
        outer,
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(15, 25, 10, 10),
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(40, 30, 0, 10),
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(20, 60, 10, 0),
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(41, 30, 0, 10),
        contains
    ));
    assert(!contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(20, 61, 10, 0),
        contains
    ));
    assert(!contains);
}


/*
 * Empty-parent containment remains anchored geometry rather than a special
 * failure state.
 */
unittest
{
    const outer =
        Region2D(10, 20, 0, 0);

    bool contains;

    assert(tryContainsAbsolute(
        outer,
        Region2D(10, 20, 0, 0),
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(11, 20, 0, 0),
        contains
    ));
    assert(!contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(10, 20, 0, 1),
        contains
    ));
    assert(!contains);
}


/*
 * Invalid containment inputs are distinguishable from valid non-containment.
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

    bool contains = true;

    assert(!tryContainsAbsolute(
        Region2D(0, 0, 10, 10),
        invalid,
        contains
    ));

    assert(!contains);

    contains = true;

    assert(!tryContainsAbsolute(
        invalid,
        Region2D.init,
        contains
    ));

    assert(!contains);
}


/*
 * Ordinary intersections.
 */
unittest
{
    Region2D result;

    const a =
        Region2D(10, 20, 30, 40);

    assert(tryIntersection(
        a,
        a,
        result
    ));

    assert(result == a);

    assert(tryIntersection(
        a,
        Region2D(15, 25, 10, 10),
        result
    ));

    assert(result ==
        Region2D(15, 25, 10, 10));

    assert(tryIntersection(
        a,
        Region2D(30, 50, 20, 20),
        result
    ));

    assert(result ==
        Region2D(30, 50, 10, 10));
}


/*
 * Disjoint and edge-touching intersections produce deterministic empty
 * geometry.
 */
unittest
{
    Region2D result;

    assert(tryIntersection(
        Region2D(0, 0, 10, 10),
        Region2D(10, 0, 10, 10),
        result
    ));

    assert(result ==
        Region2D(10, 0, 0, 10));

    assert(tryIntersection(
        Region2D(0, 0, 10, 10),
        Region2D(10, 10, 10, 10),
        result
    ));

    assert(result ==
        Region2D(10, 10, 0, 0));

    assert(tryIntersection(
        Region2D(0, 0, 10, 10),
        Region2D(20, 30, 5, 7),
        result
    ));

    assert(result ==
        Region2D(20, 30, 0, 0));
}


/*
 * Empty input geometry preserves the independently derived intersection
 * anchor.
 */
unittest
{
    Region2D result;

    assert(tryIntersection(
        Region2D(10, 0, 0, 10),
        Region2D(0, 0, 10, 10),
        result
    ));

    assert(result ==
        Region2D(10, 0, 0, 10));
}


/*
 * Intersection arithmetic remains valid at the maximum representable end.
 */
unittest
{
    Region2D result;

    const a =
        Region2D(
            size_t.max - 10,
            size_t.max - 10,
            10,
            10
        );

    const b =
        Region2D(
            size_t.max - 5,
            size_t.max - 5,
            5,
            5
        );

    assert(a.hasRepresentableExtent());
    assert(b.hasRepresentableExtent());

    assert(tryIntersection(
        a,
        b,
        result
    ));

    assert(result == b);
}


/*
 * Invalid intersection input fails without an ambiguous successful empty
 * result.
 */
unittest
{
    Region2D result =
        Region2D(1, 2, 3, 4);

    assert(!tryIntersection(
        Region2D(
            size_t.max,
            0,
            1,
            1
        ),
        Region2D.init,
        result
    ));

    assert(result == Region2D.init);
}


/*
 * Ordinary translation.
 */
unittest
{
    const source =
        Region2D(10, 20, 30, 40);

    Region2D result;

    assert(tryTranslate(
        source,
        Translation2D(
            positive(5),
            positive(7)
        ),
        result
    ));

    assert(result ==
        Region2D(15, 27, 30, 40));

    assert(tryTranslate(
        source,
        Translation2D(
            negative(5),
            negative(7)
        ),
        result
    ));

    assert(result ==
        Region2D(5, 13, 30, 40));

    assert(tryTranslate(
        source,
        Translation2D(
            negative(5),
            positive(7)
        ),
        result
    ));

    assert(result ==
        Region2D(5, 27, 30, 40));
}


/*
 * Translation can reach coordinate zero exactly but cannot underflow.
 */
unittest
{
    const source =
        Region2D(5, 7, 10, 20);

    Region2D result;

    assert(tryTranslate(
        source,
        Translation2D(
            negative(5),
            negative(7)
        ),
        result
    ));

    assert(result ==
        Region2D(0, 0, 10, 20));

    assert(!tryTranslate(
        source,
        Translation2D(
            negative(6),
            negative(7)
        ),
        result
    ));

    assert(result == Region2D.init);
}


/*
 * Positive translation may place the region exactly at the maximum
 * representable end.
 */
unittest
{
    const source =
        Region2D(10, 20, 20, 30);

    Region2D result;

    const exactX =
        size_t.max - 30;

    assert(tryTranslate(
        source,
        Translation2D(
            positive(exactX),
            positive(0)
        ),
        result
    ));

    assert(result.x ==
        size_t.max - source.width);

    assert(result.x + result.width ==
        size_t.max);

    assert(!tryTranslate(
        source,
        Translation2D(
            positive(exactX + 1),
            positive(0)
        ),
        result
    ));

    assert(result == Region2D.init);
}


/*
 * Zero magnitude is identity regardless of the stored direction.
 */
unittest
{
    const source =
        Region2D(
            size_t.max,
            size_t.max,
            0,
            0
        );

    Region2D result;

    assert(tryTranslate(
        source,
        Translation2D(
            negative(0),
            positive(0)
        ),
        result
    ));

    assert(result == source);

    assert(!tryTranslate(
        source,
        Translation2D(
            positive(1),
            positive(0)
        ),
        result
    ));

    assert(result == Region2D.init);
}


/*
 * Non-empty containment may touch every enclosing boundary exactly.
 */
unittest
{
    const outer =
        Region2D(10, 20, 30, 40);

    bool contains;

    assert(tryContainsAbsolute(
        outer,
        Region2D(10, 20, 5, 5),
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(35, 55, 5, 5),
        contains
    ));
    assert(contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(9, 20, 5, 5),
        contains
    ));
    assert(!contains);

    assert(tryContainsAbsolute(
        outer,
        Region2D(10, 19, 5, 5),
        contains
    ));
    assert(!contains);
}


/*
 * Vertical disjointness retains the independently computed empty-intersection
 * geometry.
 */
unittest
{
    Region2D result;

    assert(tryIntersection(
        Region2D(0, 0, 10, 10),
        Region2D(0, 20, 10, 5),
        result
    ));

    assert(result ==
        Region2D(0, 20, 10, 0));
}


/*
 * Ordinary zero translation is identity.
 */
unittest
{
    const source =
        Region2D(10, 20, 30, 40);

    Region2D result;

    assert(tryTranslate(
        source,
        Translation2D(
            positive(0),
            negative(0)
        ),
        result
    ));

    assert(result == source);
}


/*
 * Invalid source geometry is rejected before translation arithmetic.
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

    Region2D result =
        Region2D(1, 2, 3, 4);

    assert(!tryTranslate(
        invalid,
        Translation2D(
            positive(0),
            positive(0)
        ),
        result
    ));

    assert(result == Region2D.init);
}
