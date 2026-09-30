/++
    Package-internal approved 3 x 3 neighbourhood execution kernels.

    Public structural validation remains in raster.neighbourhood.

    This module receives only already-approved Canonical execution geometry and
    performs no public error classification.
+/
module raster.internal.neighbourhood_dispatch;

import raster.internal.compiler_capabilities :
    useLdc2111NegativeFloatNeighbourhoodRowBoundary;


/++
    Invokes one caller-supplied kernel under the same semantic attribute
    contract as the public M2.3 operation.
+/
private
T invokeApprovedNeighbourhoodKernel(alias kernel, T)(
    ref const(T)[9] neighbourhood
)
@safe
pure
nothrow
@nogc
{
    return kernel(neighbourhood);
}


/++
    Ordinary check-free Canonical executor.

    Preconditions are established by raster.neighbourhood:

    - non-empty width/height;
    - source/destination sample stride == 1;
    - complete resident one-sample source halo;
    - injective destination;
    - exact physical source/destination disjointness;
    - valid source/destination pointers and row strides.
+/
private
void executeCanonicalIntegrated(alias kernel, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t sourceOutputX,
    size_t sourceOutputY,
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
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(width != 0);
    assert(height != 0);

    const sourceStart =
        sourceBase
        + cast(ptrdiff_t) sourceOutputY * sourceRowStride
        + cast(ptrdiff_t) sourceOutputX;

    foreach (y; 0 .. height)
    {
        const centerRow =
            sourceStart
            + cast(ptrdiff_t) y * sourceRowStride;

        const row0 =
            centerRow - sourceRowStride - 1;

        const row1 =
            centerRow - 1;

        const row2 =
            centerRow + sourceRowStride - 1;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y * destinationRowStride;

        foreach (x; 0 .. width)
        {
            T[9] neighbourhood =
            [
                row0[x],
                row0[x + 1],
                row0[x + 2],

                row1[x],
                row1[x + 1],
                row1[x + 2],

                row2[x],
                row2[x + 1],
                row2[x + 2]
            ];

            destinationRow[x] =
                invokeApprovedNeighbourhoodKernel!kernel(
                    neighbourhood
                );
        }
    }
}


/++
    Preserved row-level optimization boundary for the qualified LDC/frontend
    generation.

    This source form is selected only for float + negative Canonical source row
    stride when the centralized compiler capability is true.
+/
pragma(inline, false)
private
void executeFloatRowNoInline(alias kernel)(
    scope const(float)* row0,
    scope const(float)* row1,
    scope const(float)* row2,
    scope float* destinationRow,
    size_t width
)
@trusted
pure
nothrow
@nogc
{
    foreach (x; 0 .. width)
    {
        float[9] neighbourhood =
        [
            row0[x],
            row0[x + 1],
            row0[x + 2],

            row1[x],
            row1[x + 1],
            row1[x + 2],

            row2[x],
            row2[x + 1],
            row2[x + 2]
        ];

        destinationRow[x] =
            invokeApprovedNeighbourhoodKernel!kernel(
                neighbourhood
            );
    }
}


private
void executeFloatNegativeRowsNoInline(alias kernel)(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t sourceOutputX,
    size_t sourceOutputY,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted
pure
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(sourceRowStride < 0);
    assert(width != 0);
    assert(height != 0);

    const sourceStart =
        sourceBase
        + cast(ptrdiff_t) sourceOutputY * sourceRowStride
        + cast(ptrdiff_t) sourceOutputX;

    foreach (y; 0 .. height)
    {
        const centerRow =
            sourceStart
            + cast(ptrdiff_t) y * sourceRowStride;

        const row0 =
            centerRow - sourceRowStride - 1;

        const row1 =
            centerRow - 1;

        const row2 =
            centerRow + sourceRowStride - 1;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y * destinationRowStride;

        executeFloatRowNoInline!kernel(
            row0,
            row1,
            row2,
            destinationRow,
            width
        );
    }
}


/++
    Executes one already-approved Canonical neighbourhood operation.

    This is package-internal execution policy, not public semantics.
+/
package(raster)
void executeApprovedNeighbourhood3x3(alias kernel, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t sourceOutputX,
    size_t sourceOutputY,
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
    static if (
        is(T == float)
        && useLdc2111NegativeFloatNeighbourhoodRowBoundary
    )
    {
        if (sourceRowStride < 0)
        {
            executeFloatNegativeRowsNoInline!kernel(
                sourceBase,
                sourceRowStride,
                sourceOutputX,
                sourceOutputY,
                width,
                height,
                destinationBase,
                destinationRowStride
            );

            return;
        }
    }

    executeCanonicalIntegrated!kernel(
        sourceBase,
        sourceRowStride,
        sourceOutputX,
        sourceOutputY,
        width,
        height,
        destinationBase,
        destinationRowStride
    );
}
