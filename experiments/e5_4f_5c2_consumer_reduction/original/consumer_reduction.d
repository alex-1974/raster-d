module e5_4f_5c2_consumer_reduction;

import std.stdio : writeln;


/*
 * Small-domain independent reference.
 *
 * Addresses are abstract signed integers here. This probe validates only the
 * consumer-specific byte-displacement reduction. Full-width address and wide
 * arithmetic were already established by E5.4f.5b.
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
        firstStart + cast(long) firstSize;

    const secondEnd =
        secondStart + cast(long) secondSize;

    return
           firstStart < secondEnd
        && secondStart < firstEnd;
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
    size_t sourceSampleSize,

    long targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,
    size_t targetSampleSize
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
                    sourceSampleSize
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
                            targetSampleSize
                        );

                    if (
                        byteIntervalsOverlap(
                            sourceStart,
                            sourceSampleSize,
                            targetStart,
                            targetSampleSize
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


/*
 * Consumer reduction for same-type copy.
 *
 * Every reachable sample start on either side differs from its plane base by
 * an integer multiple of sampleSize.
 *
 * Therefore:
 *
 *     sourceStart - targetStart
 *
 * has one fixed residue modulo sampleSize.
 *
 * Equal-sized sample byte intervals overlap only when that difference lies in:
 *
 *     [-(sampleSize - 1), sampleSize - 1]
 *
 * An interval of length 2*sampleSize - 1 contains at most two integers with
 * one fixed residue modulo sampleSize.
 *
 * The probe intentionally finds those candidates by enumeration. Production
 * must not do that; this is the independent reference for the reduction.
 */
@safe
pure
nothrow
@nogc
bool reducedSameTypeOverlap(
    size_t width,
    size_t height,

    long sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    long targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,

    size_t sampleSize,

    out size_t candidateCount
)
{
    assert(sampleSize != 0);

    candidateCount = 0;

    long[2] candidates;

    const baseDifference =
        sourceBase - targetBase;

    const reach =
        cast(long)(sampleSize - 1);

    for (
        long difference = -reach;
        difference <= reach;
        ++difference
    )
    {
        if (
            (difference - baseDifference)
            % cast(long) sampleSize
            != 0
        )
        {
            continue;
        }

        assert(candidateCount < candidates.length);

        candidates[candidateCount] =
            difference;

        ++candidateCount;
    }

    assert(candidateCount >= 1);
    assert(candidateCount <= 2);

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

                    const actualDifference =
                        sourceStart - targetStart;

                    foreach (
                        candidateIndex;
                        0 .. candidateCount
                    )
                    {
                        if (
                            actualDifference
                            == candidates[candidateIndex]
                        )
                        {
                            return true;
                        }
                    }
                }
            }
        }
    }

    return false;
}


/*
 * Consumer reduction for the existing exact ubyte -> float operation.
 *
 * For:
 *
 *     sourceSampleSize = 1
 *     targetSampleSize = 4
 *
 * byte overlap requires:
 *
 *     sourceStart - targetStart in [0, 3]
 *
 * so the complete candidate set is exactly:
 *
 *     0, 1, 2, 3
 */
@safe
pure
nothrow
@nogc
bool reducedUbyteToFloatOverlap(
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
                sampleStart(
                    sourceBase,
                    sourceX,
                    sourceY,
                    sourceRowStrideElements,
                    sourceSampleStrideElements,
                    ubyte.sizeof
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
                            float.sizeof
                        );

                    const difference =
                        sourceStart - targetStart;

                    if (
                        difference == 0
                        || difference == 1
                        || difference == 2
                        || difference == 3
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
    immutable size_t[5] sameTypeSampleSizes =
        [1, 2, 3, 4, 7];

    enum long sourceBase = 512;

    size_t sameTypeCases;
    size_t sameTypeOverlapCases;
    size_t maxSameTypeCandidates;

    size_t conversionCases;
    size_t conversionOverlapCases;


    foreach (width; 0 .. 3)
    {
        foreach (height; 0 .. 3)
        {
            foreach (
                sourceRow;
                cast(ptrdiff_t) -3
                    ..
                cast(ptrdiff_t) 4
            )
            {
                foreach (
                    sourceSample;
                    cast(ptrdiff_t) -3
                        ..
                    cast(ptrdiff_t) 4
                )
                {
                    foreach (
                        targetRow;
                        cast(ptrdiff_t) -3
                            ..
                        cast(ptrdiff_t) 4
                    )
                    {
                        foreach (
                            targetSample;
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


                                foreach (
                                    sampleSize;
                                    sameTypeSampleSizes
                                )
                                {
                                    const reference =
                                        bruteForceOverlap(
                                            width,
                                            height,

                                            sourceBase,
                                            sourceRow,
                                            sourceSample,
                                            sampleSize,

                                            targetBase,
                                            targetRow,
                                            targetSample,
                                            sampleSize
                                        );

                                    size_t candidateCount;

                                    const reduced =
                                        reducedSameTypeOverlap(
                                            width,
                                            height,

                                            sourceBase,
                                            sourceRow,
                                            sourceSample,

                                            targetBase,
                                            targetRow,
                                            targetSample,

                                            sampleSize,

                                            candidateCount
                                        );

                                    assert(
                                        reduced
                                        == reference
                                    );

                                    if (
                                        candidateCount
                                        > maxSameTypeCandidates
                                    )
                                    {
                                        maxSameTypeCandidates =
                                            candidateCount;
                                    }

                                    if (reference)
                                    {
                                        ++sameTypeOverlapCases;
                                    }

                                    ++sameTypeCases;
                                }


                                const conversionReference =
                                    bruteForceOverlap(
                                        width,
                                        height,

                                        sourceBase,
                                        sourceRow,
                                        sourceSample,
                                        ubyte.sizeof,

                                        targetBase,
                                        targetRow,
                                        targetSample,
                                        float.sizeof
                                    );

                                const conversionReduced =
                                    reducedUbyteToFloatOverlap(
                                        width,
                                        height,

                                        sourceBase,
                                        sourceRow,
                                        sourceSample,

                                        targetBase,
                                        targetRow,
                                        targetSample
                                    );

                                assert(
                                    conversionReduced
                                    == conversionReference
                                );

                                if (conversionReference)
                                {
                                    ++conversionOverlapCases;
                                }

                                ++conversionCases;
                            }
                        }
                    }
                }
            }
        }
    }


    assert(maxSameTypeCandidates <= 2);

    static assert(ubyte.sizeof == 1);
    static assert(float.sizeof == 4);


    writeln(
        "sameTypeCases=",
        sameTypeCases
    );

    writeln(
        "sameTypeOverlapCases=",
        sameTypeOverlapCases
    );

    writeln(
        "maxSameTypeCandidates=",
        maxSameTypeCandidates
    );

    writeln(
        "ubyteToFloatCases=",
        conversionCases
    );

    writeln(
        "ubyteToFloatOverlapCases=",
        conversionOverlapCases
    );

    writeln(
        "ubyteToFloatCandidateCount=4"
    );

    writeln(
        "consumer-specific displacement reduction: PASS"
    );
}
