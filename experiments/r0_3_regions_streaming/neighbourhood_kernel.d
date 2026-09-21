module neighbourhood_kernel;


/++
    Exact deterministic 3 x 3 weighted neighbourhood kernel for E3.3.

    Sample order:

        NW   N   NE
         W   C    E
        SW   S   SE

    Weighted sum:

          2 * NW +  3 * N  +  5 * NE
        + 7 * W  + 11 * C  + 13 * E
        +17 * SW + 19 * S  + 23 * SE

    The returned ubyte value is:

        weighted % 251

    The weights sum to 100.

    With ubyte input, the maximum weighted intermediate is therefore:

        255 * 100 = 25_500

    so uint arithmetic is comfortably exact.

    This function defines only kernel arithmetic and neighbour ordering.

    It does not define:

    - dependency expansion;
    - halo acquisition;
    - border behaviour;
    - logical/resident coordinate mapping.
+/
ubyte weightedNeighbourhood3x3(
    ubyte northWest,
    ubyte north,
    ubyte northEast,
    ubyte west,
    ubyte center,
    ubyte east,
    ubyte southWest,
    ubyte south,
    ubyte southEast
)
@safe
pure
nothrow
@nogc
{
    const uint weighted =
          cast(uint) northWest * 2
        + cast(uint) north     * 3
        + cast(uint) northEast * 5
        + cast(uint) west      * 7
        + cast(uint) center    * 11
        + cast(uint) east      * 13
        + cast(uint) southWest * 17
        + cast(uint) south     * 19
        + cast(uint) southEast * 23;

    assert(weighted <= 25_500);

    return cast(ubyte)(
        weighted % 251
    );
}


/*
 * Zero input remains zero.
 */
unittest
{
    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            0, 0, 0,
            0, 0, 0
        )
        == 0
    );
}


/*
 * Maximum ubyte input exercises the maximum exact weighted intermediate.
 *
 *     25_500 % 251 = 149
 */
unittest
{
    assert(
        weightedNeighbourhood3x3(
            255, 255, 255,
            255, 255, 255,
            255, 255, 255
        )
        == 149
    );
}


/*
 * A simple asymmetric fixture independently checks the complete expression.
 *
 * Weighted sum:
 *
 *       2 * 1 +  3 * 2 +  5 * 3
 *     + 7 * 4 + 11 * 5 + 13 * 6
 *     +17 * 7 + 19 * 8 + 23 * 9
 *
 *     = 662
 *
 *     662 % 251 = 160
 */
unittest
{
    assert(
        weightedNeighbourhood3x3(
            1, 2, 3,
            4, 5, 6,
            7, 8, 9
        )
        == 160
    );
}


/*
 * One-hot inputs prove both neighbour ordering and every individual weight.
 */
unittest
{
    assert(
        weightedNeighbourhood3x3(
            1, 0, 0,
            0, 0, 0,
            0, 0, 0
        )
        == 2
    );

    assert(
        weightedNeighbourhood3x3(
            0, 1, 0,
            0, 0, 0,
            0, 0, 0
        )
        == 3
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 1,
            0, 0, 0,
            0, 0, 0
        )
        == 5
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            1, 0, 0,
            0, 0, 0
        )
        == 7
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            0, 1, 0,
            0, 0, 0
        )
        == 11
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            0, 0, 1,
            0, 0, 0
        )
        == 13
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            0, 0, 0,
            1, 0, 0
        )
        == 17
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            0, 0, 0,
            0, 1, 0
        )
        == 19
    );

    assert(
        weightedNeighbourhood3x3(
            0, 0, 0,
            0, 0, 0,
            0, 0, 1
        )
        == 23
    );
}
