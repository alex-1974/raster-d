module imagery.raster.internal.e5_4f_5c2_production_equivalence;

import imagery.raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DByteOverlap;

import std.stdio :
    writeln;


/*
 * Independent small-domain reference.
 *
 * The chosen address domain stays far from machine-address boundaries.
 * Full-width arithmetic is already covered by the retained E5.4f research.
 */
@safe
pure
nothrow
@nogc
long sampleStart(
    long base,
    size_t x,
    size_t y,
    ptrdiff_t rowStrideElements,
    ptrdiff_t sampleStrideElements,
    size_t sampleSize
)
{
    return
          base
        + cast(long) y
            * cast(long) rowStrideElements
            * cast(long) sampleSize
        + cast(long) x
            * cast(long) sampleStrideElements
            * cast(long) sampleSize;
}


@safe
pure
nothrow
@nogc
bool byteIntervalsOverlap(
    long firstStart,
    size_t firstSize,
    long secondStart,
    size_t secondSize
)
{
    assert(firstSize != 0);
    assert(secondSize != 0);

    const firstEnd =
        firstStart
        + cast(long) firstSize;

    const secondEnd =
        secondStart
        + cast(long) secondSize;

    return
           firstStart < secondEnd
        && secondStart < firstEnd;
}


@safe
pure
nothrow
@nogc
bool bruteForceInjective(
    size_t width,
    size_t height,
    ptrdiff_t rowStrideElements,
    ptrdiff_t sampleStrideElements
)
{
    foreach (firstY; 0 .. height)
    {
        foreach (firstX; 0 .. width)
        {
            const first =
                  cast(long) firstX
                    * cast(long) sampleStrideElements
                + cast(long) firstY
                    * cast(long) rowStrideElements;

            foreach (secondY; 0 .. height)
            {
                foreach (secondX; 0 .. width)
                {
                    if (
                        firstX == secondX
                        && firstY == secondY
                    )
                    {
                        continue;
                    }

                    const second =
                          cast(long) secondX
                            * cast(long) sampleStrideElements
                        + cast(long) secondY
                            * cast(long) rowStrideElements;

                    if (first == second)
                        return false;
                }
            }
        }
    }

    return true;
}


@safe
pure
nothrow
@nogc
bool bruteForceOverlap(
    size_t width,
    size_t height,

    long sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    long targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,

    size_t sampleSize
)
{
    foreach (sourceY; 0 .. height)
    {
        foreach (sourceX; 0 .. width)
        {
            const sourceStart =
                sampleStart(
                    sourceBase,
                    sourceX,
                    sourceY,
                    sourceRowStrideElements,
                    sourceSampleStrideElements,
                    sampleSize
                );

            foreach (targetY; 0 .. height)
            {
                foreach (targetX; 0 .. width)
                {
                    const targetStart =
                        sampleStart(
                            targetBase,
                            targetX,
                            targetY,
                            targetRowStrideElements,
                            targetSampleStrideElements,
                            sampleSize
                        );

                    if (
                        byteIntervalsOverlap(
                            sourceStart,
                            sampleSize,
                            targetStart,
                            sampleSize
                        )
                    )
                    {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}


@safe
void main()
{
    size_t injectivityCases;
    size_t overlapCases;
    size_t expectedOverlapCases;
    size_t expectedDisjointCases;

    immutable size_t[5] sampleSizes =
        [1, 2, 3, 4, 7];


    /*
     * Direct production injectivity equivalence.
     */
    foreach (width; 0 .. 5)
    {
        foreach (height; 0 .. 5)
        {
            foreach (
                rowStride;
                cast(ptrdiff_t) -6
                    ..
                cast(ptrdiff_t) 7
            )
            {
                foreach (
                    sampleStride;
                    cast(ptrdiff_t) -6
                        ..
                    cast(ptrdiff_t) 7
                )
                {
                    const predicted =
                        affine2DMappingIsInjective(
                            width,
                            height,
                            rowStride,
                            sampleStride
                        );

                    const reference =
                        bruteForceInjective(
                            width,
                            height,
                            rowStride,
                            sampleStride
                        );

                    assert(
                        predicted
                        == reference
                    );

                    ++injectivityCases;
                }
            }
        }
    }


    /*
     * Direct equivalence of the composed production overlap relation.
     *
     * Maximum non-empty shape is 3x3, so brute-force comparison remains
     * deliberately small while still exercising genuine 2D mappings.
     */
    enum long sourceBase = 4096;

    foreach (width; 0 .. 4)
    {
        foreach (height; 0 .. 4)
        {
            foreach (
                sourceRowStride;
                cast(ptrdiff_t) -2
                    ..
                cast(ptrdiff_t) 3
            )
            {
                foreach (
                    sourceSampleStride;
                    cast(ptrdiff_t) -2
                        ..
                    cast(ptrdiff_t) 3
                )
                {
                    foreach (
                        targetRowStride;
                        cast(ptrdiff_t) -2
                            ..
                        cast(ptrdiff_t) 3
                    )
                    {
                        foreach (
                            targetSampleStride;
                            cast(ptrdiff_t) -2
                                ..
                            cast(ptrdiff_t) 3
                        )
                        {
                            foreach (
                                baseDelta;
                                cast(long) -5
                                    ..
                                cast(long) 6
                            )
                            {
                                const targetBase =
                                    sourceBase
                                    + baseDelta;

                                foreach (
                                    sampleSize;
                                    sampleSizes
                                )
                                {
                                    const reference =
                                        bruteForceOverlap(
                                            width,
                                            height,

                                            sourceBase,
                                            sourceRowStride,
                                            sourceSampleStride,

                                            targetBase,
                                            targetRowStride,
                                            targetSampleStride,

                                            sampleSize
                                        );

                                    const production =
                                        classifySameTypeAffine2DByteOverlap(
                                            width,
                                            height,

                                            cast(size_t) sourceBase,
                                            sourceRowStride,
                                            sourceSampleStride,

                                            cast(size_t) targetBase,
                                            targetRowStride,
                                            targetSampleStride,

                                            sampleSize
                                        );

                                    assert(
                                        production
                                        !=
                                        AffineByteOverlapRelation
                                            .arithmeticFailure
                                    );

                                    const predicted =
                                        production
                                        ==
                                        AffineByteOverlapRelation
                                            .overlap;

                                    assert(
                                        predicted
                                        == reference
                                    );

                                    if (reference)
                                    {
                                        ++expectedOverlapCases;
                                    }
                                    else
                                    {
                                        ++expectedDisjointCases;
                                    }

                                    ++overlapCases;
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    /*
     * Named envelope false-positive.
     */
    assert(
        classifySameTypeAffine2DByteOverlap(
            4,
            1,

            64,
            0,
            2,

            65,
            0,
            2,

            1
        )
        == AffineByteOverlapRelation.disjoint
    );


    /*
     * Same physical sample set in opposite traversal.
     */
    assert(
        classifySameTypeAffine2DByteOverlap(
            4,
            1,

            70,
            0,
            -2,

            64,
            0,
            2,

            1
        )
        == AffineByteOverlapRelation.overlap
    );


    /*
     * Equal multi-byte samples can overlap without equal start addresses.
     */
    assert(
        classifySameTypeAffine2DByteOverlap(
            1,
            1,

            100,
            0,
            0,

            102,
            0,
            0,

            4
        )
        == AffineByteOverlapRelation.overlap
    );


    /*
     * Full machine-address difference remains a valid relational operand.
     */
    assert(
        classifySameTypeAffine2DByteOverlap(
            1,
            1,

            0,
            0,
            0,

            size_t.max,
            0,
            0,

            1
        )
        == AffineByteOverlapRelation.disjoint
    );


    writeln(
        "injectivityCases=",
        injectivityCases
    );

    writeln(
        "overlapCases=",
        overlapCases
    );

    writeln(
        "expectedOverlapCases=",
        expectedOverlapCases
    );

    writeln(
        "expectedDisjointCases=",
        expectedDisjointCases
    );

    writeln(
        "production affine relation equivalence: PASS"
    );
}
