/++
    Internal generic exact raster conversion dispatch.

    This module extends the already-qualified exact conversion semantics to the
    universally exact type pairs frozen by M3.5.

    The historical ubyte -> float path remains delegated to its qualified
    production implementation.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.exact_conversion;

import raster.internal.affine_relation :
    affine2DMappingIsInjective;

import raster.internal.conversion_dispatch :
    ExactUbyteToFloatRasterError,
    convertUbyteToFloatRasterPlane;

import raster.internal.conversion_policy :
    isUniversallyExactRasterConversion;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Internal structural failure category for exact generic conversion.
+/
package(raster)
enum ExactRasterConversionError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}


private
bool byteIntervalsOverlap(
    size_t first,
    size_t firstSize,
    size_t second,
    size_t secondSize
)
@safe
pure
nothrow
@nogc
{
    if (first <= second)
        return second - first < firstSize;

    return first - second < secondSize;
}


/++
    Computes the smallest/largest reachable sample-start address by traversing
    already-validated affine coordinates.

    This is an allocation-free correctness fallback for generic different-size
    sample pairs. The common ubyte->float production pair retains its specialized
    checked-wide classifier.
+/
private
void reachableAddressEnvelope(T)(
    scope const(T)* base,
    ptrdiff_t rowStride,
    ptrdiff_t sampleStride,
    size_t width,
    size_t height,
    out size_t minimum,
    out size_t maximum
)
@trusted
nothrow
@nogc
{
    assert(base !is null);
    assert(width != 0);
    assert(height != 0);

    auto row = base;
    minimum = cast(size_t) base;
    maximum = minimum;

    foreach (y; 0 .. height)
    {
        auto sample = row;

        foreach (x; 0 .. width)
        {
            const address = cast(size_t) sample;

            if (address < minimum)
                minimum = address;

            if (address > maximum)
                maximum = address;

            if (x + 1 < width)
                sample += sampleStride;
        }

        if (y + 1 < height)
            row += rowStride;
    }
}


private
bool envelopesDisjoint(
    size_t firstMinimum,
    size_t firstMaximum,
    size_t firstSampleSize,
    size_t secondMinimum,
    size_t secondMaximum,
    size_t secondSampleSize
)
@safe
pure
nothrow
@nogc
{
    if (firstMaximum < secondMinimum)
        return secondMinimum - firstMaximum >= firstSampleSize;

    if (secondMaximum < firstMinimum)
        return firstMinimum - secondMaximum >= secondSampleSize;

    return false;
}


/++
    Exact sample-byte overlap fallback for arbitrary supported From/To sizes.

    The envelope pass is O(N). Exact pairwise comparison is needed only when
    the two reachable address envelopes intersect.
+/
private
bool exactSampleBytesOverlap(From, To)(
    scope const(From)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,

    scope To* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride,

    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(width != 0);
    assert(height != 0);

    size_t sourceMinimum;
    size_t sourceMaximum;
    size_t destinationMinimum;
    size_t destinationMaximum;

    reachableAddressEnvelope(
        sourceBase,
        sourceRowStride,
        sourceSampleStride,
        width,
        height,
        sourceMinimum,
        sourceMaximum
    );

    reachableAddressEnvelope(
        cast(const(To)*) destinationBase,
        destinationRowStride,
        destinationSampleStride,
        width,
        height,
        destinationMinimum,
        destinationMaximum
    );

    if (
        envelopesDisjoint(
            sourceMinimum,
            sourceMaximum,
            From.sizeof,
            destinationMinimum,
            destinationMaximum,
            To.sizeof
        )
    )
    {
        return false;
    }

    auto sourceRow = sourceBase;

    foreach (sourceY; 0 .. height)
    {
        auto sourceSample = sourceRow;

        foreach (sourceX; 0 .. width)
        {
            const sourceAddress =
                cast(size_t) sourceSample;

            auto destinationRow =
                destinationBase;

            foreach (destinationY; 0 .. height)
            {
                auto destinationSample =
                    destinationRow;

                foreach (destinationX; 0 .. width)
                {
                    if (
                        byteIntervalsOverlap(
                            sourceAddress,
                            From.sizeof,
                            cast(size_t) destinationSample,
                            To.sizeof
                        )
                    )
                    {
                        return true;
                    }

                    if (destinationX + 1 < width)
                        destinationSample += destinationSampleStride;
                }

                if (destinationY + 1 < height)
                    destinationRow += destinationRowStride;
            }

            if (sourceX + 1 < width)
                sourceSample += sourceSampleStride;
        }

        if (sourceY + 1 < height)
            sourceRow += sourceRowStride;
    }

    return false;
}


/++
    Executes an already-approved exact conversion in logical row-major order.
+/
private
void executeExactConversion(From, To)(
    scope const(From)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,

    scope To* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride,

    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
if (isUniversallyExactRasterConversion!(From, To))
{
    auto sourceRow = sourceBase;
    auto destinationRow = destinationBase;

    foreach (y; 0 .. height)
    {
        auto sourceSample = sourceRow;
        auto destinationSample = destinationRow;

        foreach (x; 0 .. width)
        {
            *destinationSample =
                cast(To) *sourceSample;

            if (x + 1 < width)
            {
                sourceSample += sourceSampleStride;
                destinationSample += destinationSampleStride;
            }
        }

        if (y + 1 < height)
        {
            sourceRow += sourceRowStride;
            destinationRow += destinationRowStride;
        }
    }
}


/++
    Performs one universally exact raster-plane conversion.

    Every semantic failure is classified before the first destination write.
+/
package(raster)
ExactRasterConversionError convertExactRasterPlane(From, To)(
    scope RasterView!From source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!To destination,
    size_t destinationPlaneIndex
)
@safe
nothrow
@nogc
if (isUniversallyExactRasterConversion!(From, To))
{
    static if (
        is(From == ubyte)
        && is(To == float)
    )
    {
        final switch (
            convertUbyteToFloatRasterPlane(
                source,
                sourcePlaneIndex,
                destination,
                destinationPlaneIndex
            )
        )
        {
            case ExactUbyteToFloatRasterError.none:
                return ExactRasterConversionError.none;

            case ExactUbyteToFloatRasterError.invalidSourcePlane:
                return ExactRasterConversionError.invalidSourcePlane;

            case ExactUbyteToFloatRasterError.invalidDestinationPlane:
                return ExactRasterConversionError.invalidDestinationPlane;

            case ExactUbyteToFloatRasterError.shapeMismatch:
                return ExactRasterConversionError.shapeMismatch;

            case ExactUbyteToFloatRasterError.nonInjectiveDestination:
                return ExactRasterConversionError.nonInjectiveDestination;

            case ExactUbyteToFloatRasterError.sourceDestinationOverlap:
                return ExactRasterConversionError.sourceDestinationOverlap;
        }
    }
    else
    {
        ptrdiff_t sourceRowStride;
        ptrdiff_t sourceSampleStride;

        if (
            !source.tryExecutionPlaneStrides(
                sourcePlaneIndex,
                sourceRowStride,
                sourceSampleStride
            )
        )
        {
            return ExactRasterConversionError.invalidSourcePlane;
        }

        ptrdiff_t destinationRowStride;
        ptrdiff_t destinationSampleStride;

        if (
            !destination.tryExecutionPlaneStrides(
                destinationPlaneIndex,
                destinationRowStride,
                destinationSampleStride
            )
        )
        {
            return ExactRasterConversionError.invalidDestinationPlane;
        }

        if (
            source.width != destination.width
            || source.height != destination.height
        )
        {
            return ExactRasterConversionError.shapeMismatch;
        }

        if (source.empty)
            return ExactRasterConversionError.none;

        if (
            !affine2DMappingIsInjective(
                destination.width,
                destination.height,
                destinationRowStride,
                destinationSampleStride
            )
        )
        {
            return ExactRasterConversionError.nonInjectiveDestination;
        }

        const sourceBase =
            source.executionRegionBase(
                sourcePlaneIndex
            );

        auto destinationBase =
            destination.executionRegionBase(
                destinationPlaneIndex
            );

        assert(sourceBase !is null);
        assert(destinationBase !is null);

        if (
            exactSampleBytesOverlap!(
                From,
                To
            )(
                sourceBase,
                sourceRowStride,
                sourceSampleStride,
                destinationBase,
                destinationRowStride,
                destinationSampleStride,
                source.width,
                source.height
            )
        )
        {
            return ExactRasterConversionError.sourceDestinationOverlap;
        }

        executeExactConversion!(
            From,
            To
        )(
            sourceBase,
            sourceRowStride,
            sourceSampleStride,
            destinationBase,
            destinationRowStride,
            destinationSampleStride,
            source.width,
            source.height
        );

        return ExactRasterConversionError.none;
    }
}
