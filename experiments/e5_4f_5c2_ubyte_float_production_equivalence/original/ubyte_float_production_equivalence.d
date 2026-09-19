module imagery.raster.internal.e5_4f_5c2_ubyte_float_production_equivalence;

import imagery.raster.internal.affine_relation :
    AffineByteOverlapRelation,
    classifyUbyteToFloatAffine2DByteOverlap;

import std.stdio :
    writeln;


/*
 * Independent small-domain byte-address oracle.
 *
 * This deliberately does not reuse production affine arithmetic or the
 * bounded Diophantine solver.
 *
 * The selected base-address domain stays far from machine-address boundaries.
 * Full-width arithmetic is already covered independently by retained E5.4f
 * research.
 */
@safe
pure
nothrow
@nogc
long sourceSampleStart(
    long base,
    size_t x,
    size_t y,
    ptrdiff_t rowStrideElements,
    ptrdiff_t sampleStrideElements
)
{
    return
          base
        + cast(long) y
            * cast(long) rowStrideElements
        + cast(long) x
            * cast(long) sampleStrideElements;
}


@safe
pure
nothrow
@nogc
long targetSampleStart(
    long base,
    size_t x,
    size_t y,
    ptrdiff_t rowStrideElements,
    ptrdiff_t sampleStrideElements
)
{
    return
          base
        + cast(long) y
            * cast(long) rowStrideElements
            * cast(long) float.sizeof
        + cast(long) x
            * cast(long) sampleStrideElements
            * cast(long) float.sizeof;
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
bool bruteForceUbyteToFloatOverlap(
    size_t width,
    size_t height,

    long sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    long targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements
)
{
    foreach (sourceY; 0 .. height)
    {
        foreach (sourceX; 0 .. width)
        {
            const sourceStart =
                sourceSampleStart(
                    sourceBase,
                    sourceX,
                    sourceY,
                    sourceRowStrideElements,
                    sourceSampleStrideElements
                );

            foreach (targetY; 0 .. height)
            {
                foreach (targetX; 0 .. width)
                {
                    const targetStart =
                        targetSampleStart(
                            targetBase,
                            targetX,
                            targetY,
                            targetRowStrideElements,
                            targetSampleStrideElements
                        );

                    if (
                        byteIntervalsOverlap(
                            sourceStart,
                            ubyte.sizeof,
                            targetStart,
                            float.sizeof
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
    static assert(ubyte.sizeof == 1);
    static assert(float.sizeof == 4);

    size_t verifiedCases;
    size_t overlapCases;
    size_t disjointCases;

    enum long sourceBase = 4096;


    /*
     * Same deterministic domain used by the retained consumer-reduction
     * research:
     *
     *     width/height       0..2
     *     all four strides  -3..3
     *     base delta        -4..4
     *
     * Total:
     *
     *     3 * 3 * 7^4 * 9
     *       = 194481
     */
    foreach (width; 0 .. 3)
    {
        foreach (height; 0 .. 3)
        {
            foreach (
                sourceRowStride;
                cast(ptrdiff_t) -3
                    ..
                cast(ptrdiff_t) 4
            )
            {
                foreach (
                    sourceSampleStride;
                    cast(ptrdiff_t) -3
                        ..
                    cast(ptrdiff_t) 4
                )
                {
                    foreach (
                        targetRowStride;
                        cast(ptrdiff_t) -3
                            ..
                        cast(ptrdiff_t) 4
                    )
                    {
                        foreach (
                            targetSampleStride;
                            cast(ptrdiff_t) -3
                                ..
                            cast(ptrdiff_t) 4
                        )
                        {
                            foreach (
                                baseDelta;
                                cast(long) -4
                                    ..
                                cast(long) 5
                            )
                            {
                                const targetBase =
                                    sourceBase
                                    + baseDelta;


                                const reference =
                                    bruteForceUbyteToFloatOverlap(
                                        width,
                                        height,

                                        sourceBase,
                                        sourceRowStride,
                                        sourceSampleStride,

                                        targetBase,
                                        targetRowStride,
                                        targetSampleStride
                                    );


                                const production =
                                    classifyUbyteToFloatAffine2DByteOverlap(
                                        width,
                                        height,

                                        cast(size_t) sourceBase,
                                        sourceRowStride,
                                        sourceSampleStride,

                                        cast(size_t) targetBase,
                                        targetRowStride,
                                        targetSampleStride
                                    );


                                /*
                                 * Every case in this deliberately narrow
                                 * physical domain is arithmetic-representable.
                                 */
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
                                    ++overlapCases;
                                else
                                    ++disjointCases;

                                ++verifiedCases;
                            }
                        }
                    }
                }
            }
        }
    }


    /*
     * All four byte positions inside one float sample overlap.
     */
    foreach (displacement; 0 .. 4)
    {
        assert(
            classifyUbyteToFloatAffine2DByteOverlap(
                1,
                1,

                64 + displacement,
                0,
                0,

                64,
                0,
                0
            )
            == AffineByteOverlapRelation.overlap
        );
    }


    /*
     * The first byte immediately after that float sample is disjoint.
     */
    assert(
        classifyUbyteToFloatAffine2DByteOverlap(
            1,
            1,

            68,
            0,
            0,

            64,
            0,
            0
        )
        == AffineByteOverlapRelation.disjoint
    );


    /*
     * Bounding-envelope false positive.
     *
     * Source bytes:
     *
     *     68, 76
     *
     * Target float intervals:
     *
     *     [64,68), [72,76)
     */
    assert(
        classifyUbyteToFloatAffine2DByteOverlap(
            2,
            1,

            68,
            0,
            8,

            64,
            0,
            2
        )
        == AffineByteOverlapRelation.disjoint
    );


    assert(
        verifiedCases
        == 194481
    );

    assert(
        overlapCases
        == 56385
    );

    assert(
        disjointCases
        == 138096
    );


    writeln(
        "ubyteToFloatCases=",
        verifiedCases
    );

    writeln(
        "ubyteToFloatOverlapCases=",
        overlapCases
    );

    writeln(
        "ubyteToFloatDisjointCases=",
        disjointCases
    );

    writeln(
        "production ubyte-to-float affine relation equivalence: PASS"
    );
}
