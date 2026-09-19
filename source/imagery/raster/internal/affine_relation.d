/++
    Package-internal finite affine raster relations.

    The production relations in this module are derived from the verified
    E5.4f affine-relation research.

    They exist only for concrete raster-operation consumers.

    This module deliberately does not define:

    - a public affine-layout abstraction;
    - a writable-target capability;
    - an alias-proof token;
    - unique ownership;
    - source/target non-overlap as a persistent property.

    Operand relations remain invocation-local.
+/
module imagery.raster.internal.affine_relation;

import core.int128 :
    Cent,
    Zero,
    add,
    mul,
    sub,
    tst,
    udivmod,
    uge,
    ugt,
    ult;


static assert(
    size_t.sizeof <= ulong.sizeof,
    "Affine relation arithmetic requires size_t no wider than ulong."
);


/++
    Exact result of one same-type finite affine sample-byte relation.
+/
package(imagery.raster)
enum AffineByteOverlapRelation : ubyte
{
    disjoint,

    overlap,

    arithmeticFailure
}


/++
    Returns whether the finite two-dimensional element mapping

        offset(x, y)
            = x * sampleStrideElements
            + y * rowStrideElements

    is injective for:

        0 <= x < width
        0 <= y < height

    Empty and single-sample mappings are vacuously injective.

    This relation establishes only that distinct logical coordinates map to
    distinct physical sample starts.

    It does not establish source/target non-overlap, ownership, exclusivity,
    noalias, contiguity or thread exclusivity.
+/
package(imagery.raster)
bool affine2DMappingIsInjective(
    size_t width,
    size_t height,
    ptrdiff_t rowStrideElements,
    ptrdiff_t sampleStrideElements
)
@safe
pure
nothrow
@nogc
{
    if (
        width == 0
        || height == 0
    )
    {
        return true;
    }

    if (
        width == 1
        && height == 1
    )
    {
        return true;
    }


    const rowMagnitude =
        ptrdiffMagnitude(
            rowStrideElements
        );

    const sampleMagnitude =
        ptrdiffMagnitude(
            sampleStrideElements
        );


    if (
        rowMagnitude == 0
        && sampleMagnitude == 0
    )
    {
        return false;
    }


    const common =
        gcdWord(
            cast(ulong) rowMagnitude,
            cast(ulong) sampleMagnitude
        );

    assert(common != 0);


    const collisionDx =
        cast(size_t)(
            cast(ulong) rowMagnitude
            / common
        );

    const collisionDy =
        cast(size_t)(
            cast(ulong) sampleMagnitude
            / common
        );


    const collisionExists =
           collisionDx <= width - 1
        && collisionDy <= height - 1;

    return !collisionExists;
}


/++
    Classifies exact physical sample-byte overlap between two equally shaped
    same-type affine planes.

    `sourceBase` and `targetBase` are the addresses of the first logical sample
    of the current source and target regions.

    Row and sample strides are expressed in elements.

    The operands are assumed to originate from already-validated RasterView
    and WritableRasterView instances. Their individual sample reachability and
    complete sample-byte representability are therefore established before
    this relation is invoked.

    Source self-aliasing is permitted.

    Destination injectivity is deliberately not established here and must be
    checked separately by the write consumer.

    For equal sample byte size S, sample-start differences have one fixed
    residue modulo S. Consequently the complete byte-overlap interval requires
    at most two displacement candidates.

    This is the consumer-specific reduction verified by
    `experiments/e5_4f_5c2_consumer_reduction`.
+/
package(imagery.raster)
AffineByteOverlapRelation classifySameTypeAffine2DByteOverlap(
    size_t width,
    size_t height,

    size_t sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    size_t targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,

    size_t sampleSize
)
@safe
pure
nothrow
@nogc
{
    if (
        width == 0
        || height == 0
    )
    {
        return
            AffineByteOverlapRelation.disjoint;
    }


    if (sampleSize == 0)
    {
        return
            AffineByteOverlapRelation.arithmeticFailure;
    }


    SignedWide[2] baseElementDifferences;

    size_t baseDifferenceCount;


    if (
        !sameTypeBaseElementDifferences(
            sourceBase,
            targetBase,
            sampleSize,
            baseElementDifferences,
            baseDifferenceCount
        )
    )
    {
        return
            AffineByteOverlapRelation.arithmeticFailure;
    }


    if (height <= width)
    {
        const sourceStep =
            signedWordFromPtrdiff(
                sourceSampleStrideElements
            );

        const targetStep =
            signedWordFromPtrdiff(
                targetSampleStrideElements
            );


        foreach (sourceY; 0 .. height)
        {
            const sourceOuter =
                multiplyPtrdiffBySize(
                    sourceRowStrideElements,
                    sourceY
                );


            foreach (targetY; 0 .. height)
            {
                const targetOuter =
                    multiplyPtrdiffBySize(
                        targetRowStrideElements,
                        targetY
                    );


                const relation =
                    classifySameTypeLinePair(
                        sourceStep,
                        width,

                        targetStep,
                        width,

                        sourceOuter,
                        targetOuter,

                        baseElementDifferences,
                        baseDifferenceCount
                    );


                if (
                    relation
                    != AffineByteOverlapRelation.disjoint
                )
                {
                    return relation;
                }
            }
        }
    }
    else
    {
        const sourceStep =
            signedWordFromPtrdiff(
                sourceRowStrideElements
            );

        const targetStep =
            signedWordFromPtrdiff(
                targetRowStrideElements
            );


        foreach (sourceX; 0 .. width)
        {
            const sourceOuter =
                multiplyPtrdiffBySize(
                    sourceSampleStrideElements,
                    sourceX
                );


            foreach (targetX; 0 .. width)
            {
                const targetOuter =
                    multiplyPtrdiffBySize(
                        targetSampleStrideElements,
                        targetX
                    );


                const relation =
                    classifySameTypeLinePair(
                        sourceStep,
                        height,

                        targetStep,
                        height,

                        sourceOuter,
                        targetOuter,

                        baseElementDifferences,
                        baseDifferenceCount
                    );


                if (
                    relation
                    != AffineByteOverlapRelation.disjoint
                )
                {
                    return relation;
                }
            }
        }
    }


    return
        AffineByteOverlapRelation.disjoint;
}


/++
    Classifies exact physical sample-byte overlap between an affine ubyte
    source and an equally shaped affine float destination.

    Source samples occupy one byte.

    Float destination samples occupy four bytes.

    Therefore source/target byte overlap requires:

        sourceStart - targetStart

    to be exactly one of:

        0, 1, 2, 3

    This fixed four-displacement reduction was established by the retained
    E5.4f.5c.2 consumer-reduction research.

    Source self-aliasing is permitted.

    Destination injectivity is a separate write-consumer requirement and is
    deliberately not established by this relation.

    The operands are expected to originate from already validated raster
    views. Their individual reachable sample intervals are therefore already
    physically representable.
+/
package(imagery.raster)
AffineByteOverlapRelation classifyUbyteToFloatAffine2DByteOverlap(
    size_t width,
    size_t height,

    size_t sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    size_t targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements
)
@safe
pure
nothrow
@nogc
{
    static assert(ubyte.sizeof == 1);
    static assert(float.sizeof == 4);

    if (
        width == 0
        || height == 0
    )
    {
        return
            AffineByteOverlapRelation.disjoint;
    }


    SignedWide[4] baseByteDifferences;

    if (
        !ubyteToFloatBaseByteDifferences(
            sourceBase,
            targetBase,
            baseByteDifferences
        )
    )
    {
        return
            AffineByteOverlapRelation.arithmeticFailure;
    }


    if (height <= width)
    {
        SignedWord sourceStep;
        SignedWord targetStep;

        if (
            !tryActiveByteStep(
                sourceSampleStrideElements,
                ubyte.sizeof,
                width,
                sourceStep
            )
            ||
            !tryActiveByteStep(
                targetSampleStrideElements,
                float.sizeof,
                width,
                targetStep
            )
        )
        {
            return
                AffineByteOverlapRelation.arithmeticFailure;
        }


        foreach (sourceY; 0 .. height)
        {
            SignedWide sourceOuter;

            if (
                !tryByteOffset(
                    sourceRowStrideElements,
                    ubyte.sizeof,
                    sourceY,
                    sourceOuter
                )
            )
            {
                return
                    AffineByteOverlapRelation.arithmeticFailure;
            }


            foreach (targetY; 0 .. height)
            {
                SignedWide targetOuter;

                if (
                    !tryByteOffset(
                        targetRowStrideElements,
                        float.sizeof,
                        targetY,
                        targetOuter
                    )
                )
                {
                    return
                        AffineByteOverlapRelation.arithmeticFailure;
                }


                const relation =
                    classifyUbyteToFloatLinePair(
                        sourceStep,
                        width,

                        targetStep,
                        width,

                        sourceOuter,
                        targetOuter,

                        baseByteDifferences
                    );


                if (
                    relation
                    != AffineByteOverlapRelation.disjoint
                )
                {
                    return relation;
                }
            }
        }
    }
    else
    {
        SignedWord sourceStep;
        SignedWord targetStep;

        if (
            !tryActiveByteStep(
                sourceRowStrideElements,
                ubyte.sizeof,
                height,
                sourceStep
            )
            ||
            !tryActiveByteStep(
                targetRowStrideElements,
                float.sizeof,
                height,
                targetStep
            )
        )
        {
            return
                AffineByteOverlapRelation.arithmeticFailure;
        }


        foreach (sourceX; 0 .. width)
        {
            SignedWide sourceOuter;

            if (
                !tryByteOffset(
                    sourceSampleStrideElements,
                    ubyte.sizeof,
                    sourceX,
                    sourceOuter
                )
            )
            {
                return
                    AffineByteOverlapRelation.arithmeticFailure;
            }


            foreach (targetX; 0 .. width)
            {
                SignedWide targetOuter;

                if (
                    !tryByteOffset(
                        targetSampleStrideElements,
                        float.sizeof,
                        targetX,
                        targetOuter
                    )
                )
                {
                    return
                        AffineByteOverlapRelation.arithmeticFailure;
                }


                const relation =
                    classifyUbyteToFloatLinePair(
                        sourceStep,
                        height,

                        targetStep,
                        height,

                        sourceOuter,
                        targetOuter,

                        baseByteDifferences
                    );


                if (
                    relation
                    != AffineByteOverlapRelation.disjoint
                )
                {
                    return relation;
                }
            }
        }
    }


    return
        AffineByteOverlapRelation.disjoint;
}


private:
struct SignedWide
{
    bool negative;
    Cent magnitude;
}

@safe
pure
nothrow
@nogc
Cent u128(
    ulong value
)
{
    Cent result;

    result.lo = value;
    result.hi = 0;

    return result;
}

@safe
pure
nothrow
@nogc
SignedWide makeSignedWide(
    bool negative,
    Cent magnitude
)
{
    if (!tst(magnitude))
        negative = false;

    return SignedWide(
        negative,
        magnitude
    );
}

@safe
pure
nothrow
@nogc
SignedWide zeroWide()
{
    return SignedWide(
        false,
        Zero
    );
}

@safe
pure
nothrow
@nogc
int compareMagnitude(
    Cent left,
    Cent right
)
{
    if (ult(left, right))
        return -1;

    if (ugt(left, right))
        return 1;

    return 0;
}

@safe
pure
nothrow
@nogc
int compareSigned(
    SignedWide left,
    SignedWide right
)
{
    if (
        !tst(left.magnitude)
        && !tst(right.magnitude)
    )
    {
        return 0;
    }

    if (left.negative != right.negative)
        return left.negative ? -1 : 1;

    const magnitudeComparison =
        compareMagnitude(
            left.magnitude,
            right.magnitude
        );

    return left.negative
        ? -magnitudeComparison
        : magnitudeComparison;
}

@safe
pure
nothrow
@nogc
bool tryAddMagnitude(
    Cent left,
    Cent right,
    out Cent result
)
{
    result =
        add(
            left,
            right
        );

    if (
        ult(result, left)
        || ult(result, right)
    )
    {
        result = Zero;
        return false;
    }

    return true;
}

@safe
pure
nothrow
@nogc
Cent subtractMagnitude(
    Cent left,
    Cent right
)
{
    assert(uge(left, right));

    return sub(
        left,
        right
    );
}

@safe
pure
nothrow
@nogc
SignedWide negateWide(
    SignedWide value
)
{
    if (!tst(value.magnitude))
        return value;

    value.negative =
        !value.negative;

    return value;
}

@safe
pure
nothrow
@nogc
bool tryAddSigned(
    SignedWide left,
    SignedWide right,
    out SignedWide result
)
{
    result =
        zeroWide();

    if (left.negative == right.negative)
    {
        Cent magnitude;

        if (
            !tryAddMagnitude(
                left.magnitude,
                right.magnitude,
                magnitude
            )
        )
        {
            return false;
        }

        result =
            makeSignedWide(
                left.negative,
                magnitude
            );

        return true;
    }


    const relation =
        compareMagnitude(
            left.magnitude,
            right.magnitude
        );

    if (relation == 0)
    {
        result =
            zeroWide();

        return true;
    }


    if (relation > 0)
    {
        result =
            makeSignedWide(
                left.negative,
                subtractMagnitude(
                    left.magnitude,
                    right.magnitude
                )
            );
    }
    else
    {
        result =
            makeSignedWide(
                right.negative,
                subtractMagnitude(
                    right.magnitude,
                    left.magnitude
                )
            );
    }

    return true;
}

@safe
pure
nothrow
@nogc
bool trySubtractSigned(
    SignedWide left,
    SignedWide right,
    out SignedWide result
)
{
    return tryAddSigned(
        left,
        negateWide(right),
        result
    );
}

@safe
pure
nothrow
@nogc
ulong signedMachineMagnitude(
    long value
)
{
    if (value >= 0)
        return cast(ulong) value;

    if (value == long.min)
    {
        return
            cast(ulong) long.max
            + 1;
    }

    return cast(ulong)(-value);
}

@safe
pure
nothrow
@nogc
SignedWide fromLong(
    long value
)
{
    return makeSignedWide(
        value < 0,
        u128(
            signedMachineMagnitude(value)
        )
    );
}

@safe
pure
nothrow
@nogc
size_t ptrdiffMagnitude(
    ptrdiff_t value
)
{
    if (value >= 0)
        return cast(size_t) value;

    if (value == ptrdiff_t.min)
    {
        return
            cast(size_t) ptrdiff_t.max
            + 1;
    }

    return cast(size_t)(-value);
}

@safe
pure
nothrow
@nogc
SignedWide addressDifference(
    size_t left,
    size_t right
)
{
    if (left >= right)
    {
        return makeSignedWide(
            false,
            u128(
                cast(ulong)(
                    left - right
                )
            )
        );
    }

    return makeSignedWide(
        true,
        u128(
            cast(ulong)(
                right - left
            )
        )
    );
}

@safe
pure
nothrow
@nogc
SignedWide multiplyPtrdiffBySize(
    ptrdiff_t value,
    size_t factor
)
{
    const magnitude =
        mul(
            u128(
                cast(ulong)
                    ptrdiffMagnitude(value)
            ),
            u128(
                cast(ulong) factor
            )
        );

    return makeSignedWide(
        value < 0,
        magnitude
    );
}

@safe
pure
nothrow
@nogc
bool tryIncrementMagnitude(
    Cent value,
    out Cent result
)
{
    return tryAddMagnitude(
        value,
        u128(1),
        result
    );
}

@safe
pure
nothrow
@nogc
bool tryFloorDivide(
    SignedWide numerator,
    SignedWide denominator,
    out SignedWide result
)
{
    result =
        zeroWide();

    if (!tst(denominator.magnitude))
        return false;

    Cent remainder;

    const quotientMagnitude =
        udivmod(
            numerator.magnitude,
            denominator.magnitude,
            remainder
        );

    const negative =
        numerator.negative
        != denominator.negative;


    if (
        negative
        && tst(remainder)
    )
    {
        Cent adjusted;

        if (
            !tryIncrementMagnitude(
                quotientMagnitude,
                adjusted
            )
        )
        {
            return false;
        }

        result =
            makeSignedWide(
                true,
                adjusted
            );

        return true;
    }


    result =
        makeSignedWide(
            negative,
            quotientMagnitude
        );

    return true;
}

@safe
pure
nothrow
@nogc
bool tryCeilDivide(
    SignedWide numerator,
    SignedWide denominator,
    out SignedWide result
)
{
    result =
        zeroWide();

    if (!tst(denominator.magnitude))
        return false;

    Cent remainder;

    const quotientMagnitude =
        udivmod(
            numerator.magnitude,
            denominator.magnitude,
            remainder
        );

    const negative =
        numerator.negative
        != denominator.negative;


    if (
        !negative
        && tst(remainder)
    )
    {
        Cent adjusted;

        if (
            !tryIncrementMagnitude(
                quotientMagnitude,
                adjusted
            )
        )
        {
            return false;
        }

        result =
            makeSignedWide(
                false,
                adjusted
            );

        return true;
    }


    result =
        makeSignedWide(
            negative,
            quotientMagnitude
        );

    return true;
}

struct SignedWord
{
    bool negative;
    ulong magnitude;
}

@safe
pure
nothrow
@nogc
SignedWord makeSignedWord(
    bool negative,
    ulong magnitude
)
{
    if (magnitude == 0)
        negative = false;

    return SignedWord(
        negative,
        magnitude
    );
}

@safe
pure
nothrow
@nogc
SignedWide fromUnsignedWord(
    ulong value
)
{
    return makeSignedWide(
        false,
        u128(value)
    );
}

@safe
pure
nothrow
@nogc
SignedWide fromSize(
    size_t value
)
{
    return fromUnsignedWord(
        cast(ulong) value
    );
}

@safe
pure
nothrow
@nogc
ulong gcdWord(
    ulong left,
    ulong right
)
{
    while (right != 0)
    {
        const remainder =
            left % right;

        left = right;
        right = remainder;
    }

    return left;
}

@safe
pure
nothrow
@nogc
Cent divideMagnitudeByWord(
    Cent numerator,
    ulong denominator,
    out ulong remainder
)
{
    assert(denominator != 0);

    Cent wideRemainder;

    const quotient =
        udivmod(
            numerator,
            u128(denominator),
            wideRemainder
        );

    assert(wideRemainder.hi == 0);

    remainder =
        wideRemainder.lo;

    return quotient;
}

@safe
pure
nothrow
@nogc
ulong remainderMagnitudeByWord(
    Cent numerator,
    ulong denominator
)
{
    ulong remainder;

    cast(void)
        divideMagnitudeByWord(
            numerator,
            denominator,
            remainder
        );

    return remainder;
}

@safe
pure
nothrow
@nogc
bool tryMultiplyMagnitudeByWord(
    Cent value,
    ulong factor,
    out Cent result
)
{
    result = Zero;

    if (
        factor == 0
        || !tst(value)
    )
    {
        return true;
    }


    result =
        mul(
            value,
            u128(factor)
        );


    Cent remainder;

    const recovered =
        udivmod(
            result,
            u128(factor),
            remainder
        );


    if (
        tst(remainder)
        || compareMagnitude(
            recovered,
            value
        ) != 0
    )
    {
        result = Zero;
        return false;
    }


    return true;
}

@safe
pure
nothrow
@nogc
bool tryMultiplySignedByWord(
    SignedWide value,
    ulong factor,
    out SignedWide result
)
{
    result =
        zeroWide();

    Cent magnitude;

    if (
        !tryMultiplyMagnitudeByWord(
            value.magnitude,
            factor,
            magnitude
        )
    )
    {
        return false;
    }


    result =
        makeSignedWide(
            value.negative,
            magnitude
        );

    return true;
}

@safe
pure
nothrow
@nogc
ulong moduloSignedWide(
    SignedWide value,
    ulong modulus
)
{
    assert(modulus != 0);

    if (modulus == 1)
        return 0;


    const remainder =
        remainderMagnitudeByWord(
            value.magnitude,
            modulus
        );


    if (
        !value.negative
        || remainder == 0
    )
    {
        return remainder;
    }


    return modulus - remainder;
}

@safe
pure
nothrow
@nogc
ulong moduloSignedWord(
    SignedWord value,
    ulong modulus
)
{
    assert(modulus != 0);

    if (modulus == 1)
        return 0;


    const remainder =
        value.magnitude % modulus;


    if (
        !value.negative
        || remainder == 0
    )
    {
        return remainder;
    }


    return modulus - remainder;
}

@safe
pure
nothrow
@nogc
ulong multiplyWordsModulo(
    ulong left,
    ulong right,
    ulong modulus
)
{
    assert(modulus != 0);

    if (modulus == 1)
        return 0;


    const product =
        mul(
            u128(left),
            u128(right)
        );


    return remainderMagnitudeByWord(
        product,
        modulus
    );
}

@safe
pure
nothrow
@nogc
bool tryModularInverseWord(
    ulong value,
    ulong modulus,
    out ulong inverse
)
{
    inverse = 0;

    assert(modulus != 0);

    if (modulus == 1)
        return true;


    value %=
        modulus;

    if (value == 0)
        return false;


    SignedWide t =
        zeroWide();

    SignedWide newT =
        fromLong(1);

    ulong r =
        modulus;

    ulong newR =
        value;


    while (newR != 0)
    {
        const quotient =
            r / newR;


        SignedWide scaledNewT;

        if (
            !tryMultiplySignedByWord(
                newT,
                quotient,
                scaledNewT
            )
        )
        {
            return false;
        }


        SignedWide nextT;

        if (
            !trySubtractSigned(
                t,
                scaledNewT,
                nextT
            )
        )
        {
            return false;
        }


        const nextR =
            r
            - quotient * newR;


        t = newT;
        newT = nextT;

        r = newR;
        newR = nextR;
    }


    if (r != 1)
        return false;


    inverse =
        moduloSignedWide(
            t,
            modulus
        );

    return true;
}

@safe
pure
nothrow
@nogc
bool tryDivideExactBySignedWord(
    SignedWide numerator,
    SignedWord denominator,
    out SignedWide quotient
)
{
    quotient =
        zeroWide();

    if (denominator.magnitude == 0)
        return false;


    ulong remainder;

    const magnitude =
        divideMagnitudeByWord(
            numerator.magnitude,
            denominator.magnitude,
            remainder
        );


    if (remainder != 0)
        return false;


    quotient =
        makeSignedWide(
            numerator.negative
                != denominator.negative,
            magnitude
        );

    return true;
}

@safe
pure
nothrow
@nogc
bool coordinateWithinCount(
    SignedWide coordinate,
    size_t count
)
{
    if (count == 0)
        return false;

    if (coordinate.negative)
        return false;


    const maximum =
        fromSize(
            count - 1
        );


    return compareSigned(
        coordinate,
        maximum
    ) <= 0;
}

enum ParameterIntervalStatus : ubyte
{
    empty,

    nonEmpty,

    arithmeticFailure
}

@safe
pure
nothrow
@nogc
ParameterIntervalStatus parameterInterval(
    SignedWide origin,
    SignedWide step,
    size_t count,
    out SignedWide minimum,
    out SignedWide maximum
)
{
    minimum =
        zeroWide();

    maximum =
        zeroWide();


    if (count == 0)
        return ParameterIntervalStatus.empty;


    assert(tst(step.magnitude));


    const lower =
        zeroWide();

    const upper =
        fromSize(
            count - 1
        );


    SignedWide lowerMinusOrigin;
    SignedWide upperMinusOrigin;


    if (
        !trySubtractSigned(
            lower,
            origin,
            lowerMinusOrigin
        )
        || !trySubtractSigned(
            upper,
            origin,
            upperMinusOrigin
        )
    )
    {
        return ParameterIntervalStatus.arithmeticFailure;
    }


    bool divisionOk;


    if (!step.negative)
    {
        divisionOk =
            tryCeilDivide(
                lowerMinusOrigin,
                step,
                minimum
            )
            &&
            tryFloorDivide(
                upperMinusOrigin,
                step,
                maximum
            );
    }
    else
    {
        divisionOk =
            tryCeilDivide(
                upperMinusOrigin,
                step,
                minimum
            )
            &&
            tryFloorDivide(
                lowerMinusOrigin,
                step,
                maximum
            );
    }


    if (!divisionOk)
        return ParameterIntervalStatus.arithmeticFailure;


    return compareSigned(
        minimum,
        maximum
    ) <= 0
        ? ParameterIntervalStatus.nonEmpty
        : ParameterIntervalStatus.empty;
}

enum DiophantineStatus : ubyte
{
    noSolution,

    hasSolution,

    arithmeticFailure
}

@safe
pure
nothrow
@nogc
DiophantineStatus boundedLinearEquation(
    SignedWord a,
    SignedWord b,
    SignedWide c,
    size_t firstCount,
    size_t secondCount
)
{
    if (
        firstCount == 0
        || secondCount == 0
    )
    {
        return DiophantineStatus.noSolution;
    }


    /*
     * Constant equation.
     */
    if (
        a.magnitude == 0
        && b.magnitude == 0
    )
    {
        return tst(c.magnitude)
            ? DiophantineStatus.noSolution
            : DiophantineStatus.hasSolution;
    }


    /*
     * One-variable special cases avoid artificial modular machinery.
     */
    if (b.magnitude == 0)
    {
        SignedWide coordinate;

        if (
            !tryDivideExactBySignedWord(
                c,
                a,
                coordinate
            )
        )
        {
            return DiophantineStatus.noSolution;
        }


        return coordinateWithinCount(
            coordinate,
            firstCount
        )
            ? DiophantineStatus.hasSolution
            : DiophantineStatus.noSolution;
    }


    if (a.magnitude == 0)
    {
        SignedWide coordinate;

        if (
            !tryDivideExactBySignedWord(
                c,
                b,
                coordinate
            )
        )
        {
            return DiophantineStatus.noSolution;
        }


        return coordinateWithinCount(
            coordinate,
            secondCount
        )
            ? DiophantineStatus.hasSolution
            : DiophantineStatus.noSolution;
    }


    const common =
        gcdWord(
            a.magnitude,
            b.magnitude
        );

    assert(common != 0);


    if (
        remainderMagnitudeByWord(
            c.magnitude,
            common
        ) != 0
    )
    {
        return DiophantineStatus.noSolution;
    }


    const reducedA =
        makeSignedWord(
            a.negative,
            a.magnitude / common
        );

    const reducedB =
        makeSignedWord(
            b.negative,
            b.magnitude / common
        );


    ulong reducedCRemainder;

    const reducedCMagnitude =
        divideMagnitudeByWord(
            c.magnitude,
            common,
            reducedCRemainder
        );

    assert(reducedCRemainder == 0);


    const reducedC =
        makeSignedWide(
            c.negative,
            reducedCMagnitude
        );


    /*
     * Solve:
     *
     *     reducedA * i = reducedC  (mod |reducedB|)
     *
     * and choose the canonical:
     *
     *     0 <= i0 < |reducedB|
     *
     * This avoids scaling arbitrary Bézout coefficients by c.
     */
    const periodI =
        reducedB.magnitude;

    assert(periodI != 0);


    ulong i0;


    if (periodI == 1)
    {
        i0 = 0;
    }
    else
    {
        const aResidue =
            moduloSignedWord(
                reducedA,
                periodI
            );

        const cResidue =
            moduloSignedWide(
                reducedC,
                periodI
            );


        ulong inverse;

        if (
            !tryModularInverseWord(
                aResidue,
                periodI,
                inverse
            )
        )
        {
            /*
             * gcd(reducedA, reducedB) == 1, so absence of an inverse would
             * indicate arithmetic failure.
             */
            return DiophantineStatus.arithmeticFailure;
        }


        i0 =
            multiplyWordsModulo(
                cResidue,
                inverse,
                periodI
            );
    }


    /*
     * Derive j0 from the exact reduced equation.
     */
    const aTimesI0 =
        makeSignedWide(
            reducedA.negative,
            mul(
                u128(reducedA.magnitude),
                u128(i0)
            )
        );


    SignedWide jNumerator;

    if (
        !trySubtractSigned(
            reducedC,
            aTimesI0,
            jNumerator
        )
    )
    {
        return DiophantineStatus.arithmeticFailure;
    }


    SignedWide j0;

    if (
        !tryDivideExactBySignedWord(
            jNumerator,
            reducedB,
            j0
        )
    )
    {
        /*
         * Congruence construction guarantees exact divisibility.
         */
        return DiophantineStatus.arithmeticFailure;
    }


    /*
     * Since i uses a positive period:
     *
     *     i = i0 + |reducedB| * k
     *
     * the corresponding j step is:
     *
     *     -reducedA * sign(reducedB)
     */
    const stepI =
        fromUnsignedWord(
            periodI
        );


    const stepJ =
        makeSignedWide(
            reducedA.negative
                == reducedB.negative,
            u128(
                reducedA.magnitude
            )
        );


    SignedWide firstMinimum;
    SignedWide firstMaximum;

    const firstInterval =
        parameterInterval(
            fromUnsignedWord(i0),
            stepI,
            firstCount,
            firstMinimum,
            firstMaximum
        );


    if (
        firstInterval
        == ParameterIntervalStatus.arithmeticFailure
    )
    {
        return DiophantineStatus.arithmeticFailure;
    }


    if (
        firstInterval
        == ParameterIntervalStatus.empty
    )
    {
        return DiophantineStatus.noSolution;
    }


    SignedWide secondMinimum;
    SignedWide secondMaximum;

    const secondInterval =
        parameterInterval(
            j0,
            stepJ,
            secondCount,
            secondMinimum,
            secondMaximum
        );


    if (
        secondInterval
        == ParameterIntervalStatus.arithmeticFailure
    )
    {
        return DiophantineStatus.arithmeticFailure;
    }


    if (
        secondInterval
        == ParameterIntervalStatus.empty
    )
    {
        return DiophantineStatus.noSolution;
    }


    /*
     * The two k intervals must intersect.
     */
    if (
        compareSigned(
            firstMinimum,
            secondMaximum
        ) > 0
        ||
        compareSigned(
            secondMinimum,
            firstMaximum
        ) > 0
    )
    {
        return DiophantineStatus.noSolution;
    }


    return DiophantineStatus.hasSolution;
}


SignedWord signedWordFromPtrdiff(
    ptrdiff_t value
)
@safe
pure
nothrow
@nogc
{
    return makeSignedWord(
        value < 0,
        cast(ulong)
            ptrdiffMagnitude(value)
    );
}


/*
 * For equal sample byte size S:
 *
 *     sourceStart - targetStart
 *
 * must lie in:
 *
 *     [-(S - 1), S - 1]
 *
 * and has one fixed residue modulo S.
 *
 * Therefore there are at most two possible byte displacements.
 *
 * This helper converts those displacement candidates into the corresponding
 * base-address difference measured in elements:
 *
 *     (targetBase - sourceBase + displacement) / S
 */
bool sameTypeBaseElementDifferences(
    size_t sourceBase,
    size_t targetBase,
    size_t sampleSize,
    out SignedWide[2] differences,
    out size_t differenceCount
)
@safe
pure
nothrow
@nogc
{
    differences[] =
        SignedWide.init;

    differenceCount = 0;


    if (sampleSize == 0)
        return false;


    const sampleWord =
        cast(ulong) sampleSize;

    const sourceMinusTarget =
        addressDifference(
            sourceBase,
            targetBase
        );

    const residue =
        moduloSignedWide(
            sourceMinusTarget,
            sampleWord
        );

    const denominator =
        makeSignedWord(
            false,
            sampleWord
        );


    SignedWide displacement =
        fromUnsignedWord(
            residue
        );

    SignedWide numerator;

    if (
        !trySubtractSigned(
            displacement,
            sourceMinusTarget,
            numerator
        )
    )
    {
        return false;
    }


    if (
        !tryDivideExactBySignedWord(
            numerator,
            denominator,
            differences[0]
        )
    )
    {
        return false;
    }


    differenceCount = 1;


    if (residue == 0)
        return true;


    displacement =
        makeSignedWide(
            true,
            u128(
                sampleWord
                - residue
            )
        );


    if (
        !trySubtractSigned(
            displacement,
            sourceMinusTarget,
            numerator
        )
    )
    {
        return false;
    }


    if (
        !tryDivideExactBySignedWord(
            numerator,
            denominator,
            differences[1]
        )
    )
    {
        return false;
    }


    differenceCount = 2;

    return true;
}


AffineByteOverlapRelation classifySameTypeLinePair(
    SignedWord sourceStep,
    size_t sourceCount,

    SignedWord targetStep,
    size_t targetCount,

    SignedWide sourceOuter,
    SignedWide targetOuter,

    const SignedWide[2] baseElementDifferences,
    size_t baseDifferenceCount
)
@safe
pure
nothrow
@nogc
{
    assert(baseDifferenceCount >= 1);
    assert(baseDifferenceCount <= 2);


    const targetCoefficient =
        makeSignedWord(
            !targetStep.negative,
            targetStep.magnitude
        );


    foreach (
        differenceIndex;
        0 .. baseDifferenceCount
    )
    {
        SignedWide withTargetOuter;

        if (
            !tryAddSigned(
                baseElementDifferences[
                    differenceIndex
                ],
                targetOuter,
                withTargetOuter
            )
        )
        {
            return
                AffineByteOverlapRelation.arithmeticFailure;
        }


        SignedWide rhs;

        if (
            !trySubtractSigned(
                withTargetOuter,
                sourceOuter,
                rhs
            )
        )
        {
            return
                AffineByteOverlapRelation.arithmeticFailure;
        }


        final switch (
            boundedLinearEquation(
                sourceStep,
                targetCoefficient,
                rhs,
                sourceCount,
                targetCount
            )
        )
        {
            case DiophantineStatus.noSolution:
                break;

            case DiophantineStatus.hasSolution:
                return
                    AffineByteOverlapRelation.overlap;

            case DiophantineStatus.arithmeticFailure:
                return
                    AffineByteOverlapRelation.arithmeticFailure;
        }
    }


    return
        AffineByteOverlapRelation.disjoint;
}


/*
 * Converts an active element stride into its signed physical byte step.
 *
 * With zero/one logical sample the step is not observable and zero is used.
 */
bool tryActiveByteStep(
    ptrdiff_t strideElements,
    size_t sampleSize,
    size_t logicalCount,
    out SignedWord step
)
@safe
pure
nothrow
@nogc
{
    step =
        makeSignedWord(
            false,
            0
        );

    if (logicalCount <= 1)
        return true;


    const wide =
        multiplyPtrdiffBySize(
            strideElements,
            sampleSize
        );


    if (wide.magnitude.hi != 0)
        return false;


    step =
        makeSignedWord(
            wide.negative,
            wide.magnitude.lo
        );

    return true;
}


/*
 * Computes:
 *
 *     strideElements * sampleSize * coordinate
 *
 * in the existing sign+magnitude wide carrier.
 */
bool tryByteOffset(
    ptrdiff_t strideElements,
    size_t sampleSize,
    size_t coordinate,
    out SignedWide offset
)
@safe
pure
nothrow
@nogc
{
    const byteStride =
        multiplyPtrdiffBySize(
            strideElements,
            sampleSize
        );

    return tryMultiplySignedByWord(
        byteStride,
        cast(ulong) coordinate,
        offset
    );
}


/*
 * For ubyte -> float:
 *
 *     sourceStart - targetStart
 *
 * must equal one of:
 *
 *     0, 1, 2, 3
 *
 * Therefore the right-hand side base term is:
 *
 *     targetBase - sourceBase + displacement
 */
bool ubyteToFloatBaseByteDifferences(
    size_t sourceBase,
    size_t targetBase,
    out SignedWide[4] differences
)
@safe
pure
nothrow
@nogc
{
    differences[] =
        SignedWide.init;

    const targetMinusSource =
        addressDifference(
            targetBase,
            sourceBase
        );


    foreach (displacement; 0 .. differences.length)
    {
        if (
            !tryAddSigned(
                targetMinusSource,
                fromUnsignedWord(
                    cast(ulong) displacement
                ),
                differences[displacement]
            )
        )
        {
            return false;
        }
    }


    return true;
}


AffineByteOverlapRelation classifyUbyteToFloatLinePair(
    SignedWord sourceStep,
    size_t sourceCount,

    SignedWord targetStep,
    size_t targetCount,

    SignedWide sourceOuter,
    SignedWide targetOuter,

    const SignedWide[4] baseByteDifferences
)
@safe
pure
nothrow
@nogc
{
    const targetCoefficient =
        makeSignedWord(
            !targetStep.negative,
            targetStep.magnitude
        );


    foreach (baseDifference; baseByteDifferences)
    {
        SignedWide withTargetOuter;

        if (
            !tryAddSigned(
                baseDifference,
                targetOuter,
                withTargetOuter
            )
        )
        {
            return
                AffineByteOverlapRelation.arithmeticFailure;
        }


        SignedWide rhs;

        if (
            !trySubtractSigned(
                withTargetOuter,
                sourceOuter,
                rhs
            )
        )
        {
            return
                AffineByteOverlapRelation.arithmeticFailure;
        }


        final switch (
            boundedLinearEquation(
                sourceStep,
                targetCoefficient,
                rhs,
                sourceCount,
                targetCount
            )
        )
        {
            case DiophantineStatus.noSolution:
                break;

            case DiophantineStatus.hasSolution:
                return
                    AffineByteOverlapRelation.overlap;

            case DiophantineStatus.arithmeticFailure:
                return
                    AffineByteOverlapRelation.arithmeticFailure;
        }
    }


    return
        AffineByteOverlapRelation.disjoint;
}


version (unittest)
{


/*
 * Every byte inside one float sample overlaps.
 */
unittest
{
    foreach (offset; 0 .. 4)
    {
        assert(
            classifyUbyteToFloatAffine2DByteOverlap(
                1,
                1,

                64 + offset,
                0,
                0,

                64,
                0,
                0
            )
            == AffineByteOverlapRelation.overlap
        );
    }
}


/*
 * The first byte immediately after the float interval is disjoint.
 */
unittest
{
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
}


/*
 * Overlapping address envelopes do not imply actual sample-byte overlap.
 *
 * Source bytes:
 *
 *     68, 76
 *
 * Target float intervals:
 *
 *     [64,68), [72,76)
 */
unittest
{
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
}

/*
 * Empty mappings are vacuously injective without observing either stride.
 */
unittest
{
    assert(
        affine2DMappingIsInjective(
            0,
            size_t.max,
            ptrdiff_t.min,
            ptrdiff_t.min
        )
    );

    assert(
        affine2DMappingIsInjective(
            size_t.max,
            0,
            ptrdiff_t.min,
            ptrdiff_t.min
        )
    );
}


/*
 * One sample remains injective even with zero strides.
 */
unittest
{
    assert(
        affine2DMappingIsInjective(
            1,
            1,
            0,
            0
        )
    );
}


/*
 * Traversed zero strides alias logical coordinates.
 */
unittest
{
    assert(
        !affine2DMappingIsInjective(
            3,
            1,
            17,
            0
        )
    );

    assert(
        !affine2DMappingIsInjective(
            1,
            3,
            0,
            -17
        )
    );
}


/*
 * Named finite-grid research cases.
 */
unittest
{
    assert(
        affine2DMappingIsInjective(
            4,
            3,
            4,
            1
        )
    );

    assert(
        affine2DMappingIsInjective(
            4,
            3,
            -4,
            1
        )
    );

    assert(
        !affine2DMappingIsInjective(
            3,
            2,
            2,
            1
        )
    );

    assert(
        !affine2DMappingIsInjective(
            4,
            3,
            6,
            4
        )
    );

    assert(
        affine2DMappingIsInjective(
            2,
            3,
            3,
            2
        )
    );
}


/*
 * ptrdiff_t.min magnitude handling does not use signed negation.
 */
unittest
{
    assert(
        !affine2DMappingIsInjective(
            2,
            2,
            ptrdiff_t.min,
            ptrdiff_t.min
        )
    );

    assert(
        affine2DMappingIsInjective(
            2,
            2,
            ptrdiff_t.min,
            1
        )
    );
}


/*
 * Bounding-envelope counterexample from E5.4f.4:
 *
 * source starts: 64,66,68,70
 * target starts: 65,67,69,71
 *
 * The envelopes overlap but actual one-byte samples do not.
 */
unittest
{
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
}


/*
 * Genuine interleaved overlap.
 */
unittest
{
    assert(
        classifySameTypeAffine2DByteOverlap(
            4,
            1,

            64,
            0,
            2,

            66,
            0,
            2,

            1
        )
        == AffineByteOverlapRelation.overlap
    );
}


/*
 * Reverse traversal over the same sample set overlaps exactly.
 */
unittest
{
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
}


/*
 * Equal four-byte samples may overlap with different sample-start addresses.
 */
unittest
{
    assert(
        classifySameTypeAffine2DByteOverlap(
            1,
            1,

            64,
            0,
            0,

            65,
            0,
            0,

            4
        )
        == AffineByteOverlapRelation.overlap
    );
}


/*
 * One logical sample makes both stride magnitudes irrelevant.
 */
unittest
{
    assert(
        classifySameTypeAffine2DByteOverlap(
            1,
            1,

            64,
            ptrdiff_t.min,
            ptrdiff_t.min,

            64,
            ptrdiff_t.max,
            ptrdiff_t.max,

            1
        )
        == AffineByteOverlapRelation.overlap
    );
}


/*
 * Full machine-address separation remains representable.
 */
unittest
{
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
}

}
