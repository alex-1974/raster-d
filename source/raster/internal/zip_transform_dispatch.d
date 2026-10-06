/++
    Invocation-local execution of validated same-type zip transforms.

    Canonical unit-sample-stride layouts use one direct row/pointer executor.
    Universal layouts remain with the public operation's semantic traversal.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.zip_transform_dispatch;


/++
    Invokes the already compile-time-qualified zip transform.
+/
private
T invokeApprovedZipTransform(alias transform, T)(
    T left,
    T right
)
@safe
pure
nothrow
@nogc
{
    return transform(left, right);
}


/++
    Safety: the caller has validated all three retained views, matching shape,
    injective destination mapping and exact destination disjointness from both
    input sample-byte sets.

    All sample strides are one. Retained validation guarantees every reachable
    row/sample pointer is valid for the supplied signed row strides.

    This trusted boundary only forms bounded row pointers and reads/writes
    already-valid samples. Neither input pointer escapes and no persistent
    noalias property is claimed.
+/
private
void executeCanonicalZipTransform(alias transform, T)(
    scope const(T)* leftBase,
    ptrdiff_t leftRowStride,

    scope const(T)* rightBase,
    ptrdiff_t rightRowStride,

    size_t width,
    size_t height,

    scope T* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted
pure
nothrow
@nogc
{
    assert(leftBase !is null);
    assert(rightBase !is null);
    assert(destinationBase !is null);
    assert(width != 0);
    assert(height != 0);

    foreach (y; 0 .. height)
    {
        const leftRow =
            leftBase
            + cast(ptrdiff_t) y
                * leftRowStride;

        const rightRow =
            rightBase
            + cast(ptrdiff_t) y
                * rightRowStride;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y
                * destinationRowStride;

        foreach (x; 0 .. width)
        {
            destinationRow[x] =
                invokeApprovedZipTransform!transform(
                    leftRow[x],
                    rightRow[x]
                );
        }
    }
}


/++
    Executes a zip transform only when all validated sample strides are one.

    Returns false without reading, writing or invoking transform for Universal
    layouts. Structural and physical checks belong to the caller.
+/
package(raster)
bool executeApprovedCanonicalZipTransform(alias transform, T)(
    scope const(T)* leftBase,
    ptrdiff_t leftRowStride,
    ptrdiff_t leftSampleStride,

    scope const(T)* rightBase,
    ptrdiff_t rightRowStride,
    ptrdiff_t rightSampleStride,

    size_t width,
    size_t height,

    scope T* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride
)
@safe
pure
nothrow
@nogc
{
    if (
        leftSampleStride != 1
        || rightSampleStride != 1
        || destinationSampleStride != 1
    )
    {
        return false;
    }

    executeCanonicalZipTransform!transform(
        leftBase,
        leftRowStride,
        rightBase,
        rightRowStride,
        width,
        height,
        destinationBase,
        destinationRowStride
    );

    return true;
}


version (unittest)
{

private
float mustNotRun(
    float left,
    float right
)
@safe
pure
nothrow
@nogc
{
    assert(0);
}


unittest
{
    assert(
        !executeApprovedCanonicalZipTransform!mustNotRun(
            cast(const(float)*) null,
            4,
            2,
            cast(const(float)*) null,
            4,
            1,
            2,
            2,
            cast(float*) null,
            4,
            1
        )
    );

    assert(
        !executeApprovedCanonicalZipTransform!mustNotRun(
            cast(const(float)*) null,
            4,
            1,
            cast(const(float)*) null,
            4,
            -1,
            2,
            2,
            cast(float*) null,
            4,
            1
        )
    );
}

} // version (unittest)
