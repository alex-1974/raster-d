/++
    Shared exact overlap checks for already-validated same-type raster planes.

    This module centralizes the byte-overlap decision used by destination-
    oriented point operations. It deliberately contains no public API.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.same_type_overlap;

import raster.internal.affine_relation :
    AffineByteOverlapRelation;

import raster.internal.validated_affine_relation :
    classifyValidatedSameTypeAffine2DByteOverlap;


/++
    Exact allocation-free fallback for same-type sample-byte overlap.

    The normal path uses the checked-wide affine classifier. This fallback is
    reached only if that classifier reports arithmetic failure.

    The operands originate from validated non-empty raster views, therefore the
    supplied sample pointers and every reachable pointer formed by the supplied
    strides are valid.

    For equal-sized T samples, two byte intervals overlap exactly when the
    absolute distance between sample starts is less than T.sizeof.
+/
private
bool sameTypeSampleBytesOverlapFallback(T)(
    scope const(T)* firstBase,
    ptrdiff_t firstRowStrideElements,
    ptrdiff_t firstSampleStrideElements,

    scope const(T)* secondBase,
    ptrdiff_t secondRowStrideElements,
    ptrdiff_t secondSampleStrideElements,

    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    assert(firstBase !is null);
    assert(secondBase !is null);
    assert(width != 0);
    assert(height != 0);

    auto firstRow =
        firstBase;

    foreach (firstY; 0 .. height)
    {
        auto firstSample =
            firstRow;

        foreach (firstX; 0 .. width)
        {
            const firstAddress =
                cast(size_t) firstSample;

            auto secondRow =
                secondBase;

            foreach (secondY; 0 .. height)
            {
                auto secondSample =
                    secondRow;

                foreach (secondX; 0 .. width)
                {
                    const secondAddress =
                        cast(size_t) secondSample;

                    const distance =
                        firstAddress <= secondAddress
                        ? secondAddress - firstAddress
                        : firstAddress - secondAddress;

                    if (distance < T.sizeof)
                        return true;

                    if (secondX + 1 < width)
                    {
                        secondSample +=
                            secondSampleStrideElements;
                    }
                }

                if (secondY + 1 < height)
                {
                    secondRow +=
                        secondRowStrideElements;
                }
            }

            if (firstX + 1 < width)
            {
                firstSample +=
                    firstSampleStrideElements;
            }
        }

        if (firstY + 1 < height)
        {
            firstRow +=
                firstRowStrideElements;
        }
    }

    return false;
}


/++
    Returns whether two already-validated same-type non-empty plane regions
    overlap in reachable sample bytes.

    Both operands must describe the same logical width/height. Injectivity is
    not required for either operand because this helper only answers physical
    byte overlap.

    No allocation, retention or scheduling occurs.
+/
package(raster)
bool validatedSameTypePlaneRegionsOverlap(T)(
    scope const(T)* firstBase,
    ptrdiff_t firstRowStrideElements,
    ptrdiff_t firstSampleStrideElements,

    scope const(T)* secondBase,
    ptrdiff_t secondRowStrideElements,
    ptrdiff_t secondSampleStrideElements,

    size_t width,
    size_t height
)
@safe
nothrow
@nogc
{
    assert(firstBase !is null);
    assert(secondBase !is null);
    assert(width != 0);
    assert(height != 0);

    final switch (
        classifyValidatedSameTypeAffine2DByteOverlap(
            width,
            height,

            cast(size_t) firstBase,
            firstRowStrideElements,
            firstSampleStrideElements,

            cast(size_t) secondBase,
            secondRowStrideElements,
            secondSampleStrideElements,

            T.sizeof
        )
    )
    {
        case AffineByteOverlapRelation.overlap:
            return true;

        case AffineByteOverlapRelation.disjoint:
            return false;

        case AffineByteOverlapRelation.arithmeticFailure:
            return sameTypeSampleBytesOverlapFallback(
                firstBase,
                firstRowStrideElements,
                firstSampleStrideElements,

                secondBase,
                secondRowStrideElements,
                secondSampleStrideElements,

                width,
                height
            );
    }
}
