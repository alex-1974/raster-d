module decomposition_oracle;

import imagery.raster.region : Region2D;
import region_algebra : tryContainsAbsolute;


/++
    Diagnostic result for the bounded E3.1.3 decomposition oracle.

    This enum is research-only and is not a proposed production error model.
+/
enum DecompositionIssue : ubyte
{
    none,
    invalidTarget,
    oracleCapacityExceeded,
    invalidMember,
    memberOutsideTarget,
    overlap,
    missingCoverage
}


/++
    Deliberate upper bound for the bitmap-backed research oracle.

    Large-coordinate correctness is tested separately by E3.1.1 and E3.1.2.
+/
enum size_t MAX_ORACLE_PIXELS =
    1024 * 1024;


/++
    Validates that `members` form an exact non-overlapping pixel decomposition
    of `target`.

    Successful decomposition means:

    - every non-empty member is contained in `target`;
    - no target pixel is covered more than once;
    - every target pixel is covered exactly once;
    - no non-empty member produces pixels outside `target`.

    Empty members contribute no coverage. They may be anchored anywhere, but
    their own Region2D geometry must remain representable.

    The bitmap implementation is intentionally limited to
    `MAX_ORACLE_PIXELS`. Exceeding that bound is an oracle-capacity condition,
    not invalid target geometry.
+/
bool tryValidateDecomposition(
    Region2D target,
    scope const(Region2D)[] members,
    out DecompositionIssue issue
)
@safe
{
    issue =
        DecompositionIssue.none;

    if (!target.hasRepresentableExtent())
    {
        issue =
            DecompositionIssue.invalidTarget;

        return false;
    }

    size_t pixelCount;

    if (target.width != 0)
    {
        if (target.height >
            size_t.max / target.width)
        {
            issue =
                DecompositionIssue.oracleCapacityExceeded;

            return false;
        }

        pixelCount =
            target.width * target.height;
    }

    if (pixelCount > MAX_ORACLE_PIXELS)
    {
        issue =
            DecompositionIssue.oracleCapacityExceeded;

        return false;
    }

    auto coverage =
        new ubyte[pixelCount];

    size_t coveredPixels = 0;

    foreach (const member; members)
    {
        if (!member.hasRepresentableExtent())
        {
            issue =
                DecompositionIssue.invalidMember;

            return false;
        }

        /*
         * Empty members produce no output samples and therefore cannot add
         * overlap, gaps or outside-target pixels.
         */
        if (member.empty())
        {
            continue;
        }

        bool contained;

        if (!tryContainsAbsolute(
            target,
            member,
            contained
        ))
        {
            /*
             * The target was already validated. Reaching this branch therefore
             * means that the member failed geometry validation.
             */
            issue =
                DecompositionIssue.invalidMember;

            return false;
        }

        if (!contained)
        {
            issue =
                DecompositionIssue.memberOutsideTarget;

            return false;
        }

        const memberOffsetX =
            member.x - target.x;

        const memberOffsetY =
            member.y - target.y;

        foreach (y; 0 .. member.height)
        {
            const targetY =
                memberOffsetY + y;

            foreach (x; 0 .. member.width)
            {
                const targetX =
                    memberOffsetX + x;

                /*
                 * Containment proves:
                 *
                 *     targetX < target.width
                 *     targetY < target.height
                 *
                 * and pixelCount was checked before allocation.
                 */
                const index =
                    targetY * target.width
                    + targetX;

                if (coverage[index] != 0)
                {
                    issue =
                        DecompositionIssue.overlap;

                    return false;
                }

                coverage[index] = 1;
                ++coveredPixels;
            }
        }
    }

    if (coveredPixels != pixelCount)
    {
        issue =
            DecompositionIssue.missingCoverage;

        return false;
    }

    return true;
}


/*
 * A caller may validate a borrowed slice of stack-resident decomposition
 * metadata.
 *
 * tryValidateDecomposition does not retain the members slice. Its public
 * lifetime contract therefore accepts scope-borrowed input under DIP1000.
 */
unittest
{
    const target =
        Region2D(
            100,
            200,
            4,
            3
        );

    const Region2D[1] members =
    [
        target
    ];

    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            target,
            members[],
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );
}


/*
 * One member equal to the complete target is a valid decomposition.
 */
unittest
{
    const target =
        Region2D(100, 200, 4, 3);

    const Region2D[] members =
    [
        target
    ];

    DecompositionIssue issue;

    assert(tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.none);
}


/*
 * Horizontal strips exactly partition a target with non-zero logical origin.
 */
unittest
{
    const target =
        Region2D(100, 200, 4, 3);

    const Region2D[] members =
    [
        Region2D(100, 200, 4, 1),
        Region2D(100, 201, 4, 1),
        Region2D(100, 202, 4, 1)
    ];

    DecompositionIssue issue;

    assert(tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.none);
}


/*
 * Vertical strips exactly partition the same target.
 */
unittest
{
    const target =
        Region2D(100, 200, 4, 3);

    const Region2D[] members =
    [
        Region2D(100, 200, 1, 3),
        Region2D(101, 200, 1, 3),
        Region2D(102, 200, 1, 3),
        Region2D(103, 200, 1, 3)
    ];

    DecompositionIssue issue;

    assert(tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.none);
}


/*
 * Irregular rectangles may still form an exact decomposition.
 */
unittest
{
    const target =
        Region2D(50, 70, 5, 4);

    const Region2D[] members =
    [
        Region2D(50, 70, 5, 1),
        Region2D(50, 71, 2, 2),
        Region2D(52, 71, 3, 2),
        Region2D(50, 73, 5, 1)
    ];

    DecompositionIssue issue;

    assert(tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.none);
}


/*
 * A bounded target can be decomposed into individual pixels.
 */
unittest
{
    const target =
        Region2D(7, 9, 3, 2);

    const Region2D[] members =
    [
        Region2D(7, 9, 1, 1),
        Region2D(8, 9, 1, 1),
        Region2D(9, 9, 1, 1),
        Region2D(7, 10, 1, 1),
        Region2D(8, 10, 1, 1),
        Region2D(9, 10, 1, 1)
    ];

    DecompositionIssue issue;

    assert(tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.none);
}


/*
 * Overlap is detected even if the union would otherwise cover the target.
 */
unittest
{
    const target =
        Region2D(0, 0, 4, 4);

    const Region2D[] members =
    [
        Region2D(0, 0, 3, 4),
        Region2D(2, 0, 2, 4)
    ];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.overlap);
}


/*
 * Missing target pixels are detected independently of overlap.
 */
unittest
{
    const target =
        Region2D(0, 0, 4, 4);

    const Region2D[] members =
    [
        Region2D(0, 0, 2, 4),
        Region2D(2, 0, 2, 3)
    ];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.missingCoverage);
}


/*
 * A non-empty member may not produce pixels outside the target.
 */
unittest
{
    const target =
        Region2D(10, 20, 4, 4);

    const Region2D[] members =
    [
        Region2D(9, 20, 2, 4),
        Region2D(11, 20, 3, 4)
    ];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.memberOutsideTarget);
}


/*
 * Invalid member geometry is distinct from ordinary outside-target geometry.
 */
unittest
{
    const target =
        Region2D(0, 0, 4, 4);

    const Region2D[] members =
    [
        Region2D(
            size_t.max,
            0,
            1,
            1
        )
    ];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.invalidMember);
}


/*
 * Invalid target geometry is rejected before any bitmap accounting.
 */
unittest
{
    const target =
        Region2D(
            size_t.max,
            0,
            1,
            1
        );

    const Region2D[] members = [];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.invalidTarget);
}


/*
 * Oracle capacity is not confused with invalid geometry.
 */
unittest
{
    const target =
        Region2D(
            0,
            0,
            MAX_ORACLE_PIXELS + 1,
            1
        );

    assert(target.hasRepresentableExtent());

    const Region2D[] members = [];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.oracleCapacityExceeded);
}


/*
 * Bitmap-area multiplication is checked before it can overflow.
 *
 * The target geometry itself is representable; only this deliberately bounded
 * research oracle cannot account for its pixel coverage.
 */
unittest
{
    const target =
        Region2D(
            0,
            0,
            size_t.max,
            2
        );

    assert(target.hasRepresentableExtent());

    const Region2D[] members = [];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.oracleCapacityExceeded);
}


/*
 * Empty targets require no coverage.
 *
 * Empty decomposition members are ignored after representability validation,
 * even when their anchors lie outside the target.
 */
unittest
{
    const target =
        Region2D(100, 200, 0, 10);

    const Region2D[] members =
    [
        Region2D(100, 200, 0, 10),
        Region2D(999, 888, 0, 0)
    ];

    DecompositionIssue issue;

    assert(tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.none);
}


/*
 * A non-empty member cannot decompose an empty target.
 */
unittest
{
    const target =
        Region2D(100, 200, 0, 10);

    const Region2D[] members =
    [
        Region2D(100, 200, 1, 1)
    ];

    DecompositionIssue issue;

    assert(!tryValidateDecomposition(
        target,
        members,
        issue
    ));

    assert(issue ==
        DecompositionIssue.memberOutsideTarget);
}
