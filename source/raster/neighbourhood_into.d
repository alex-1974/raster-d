/++
    Generic destination-oriented fixed-shape raster neighbourhood operation.

    The existing qualified centered 3 x 3 operation remains the production
    specialization for that exact shape.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.neighbourhood_into;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective;

import raster.internal.validated_affine_relation :
    classifyValidatedSameTypeAffine2DRectanglesByteOverlap;

import raster.neighbourhood :
    RasterNeighbourhood3x3Error,
    tryApplyRasterNeighbourhood3x3;

import raster.region :
    Region2D;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Semantic failure category for generic fixed-shape neighbourhood execution.
+/
enum RasterNeighbourhoodError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    destinationShapeMismatch,
    unsatisfiedNeighbourhood,
    nonInjectiveDestination,
    sourceDestinationOverlap
}


/++
    Invokes one caller-supplied fixed-shape kernel under the public attribute
    contract.
+/
private
T invokeNeighbourhoodKernel(alias Shape, alias kernel, T)(
    ref const(T)[Shape.sampleCount] neighbourhood
)
@safe
pure
nothrow
@nogc
{
    return kernel(neighbourhood);
}


/++
    Exact allocation-free fallback for required-source/destination overlap.
+/
private
bool asymmetricSampleBytesOverlapFallback(T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,
    size_t sourceWidth,
    size_t sourceHeight,

    scope T* destinationBase,
    ptrdiff_t destinationRowStrideElements,
    ptrdiff_t destinationSampleStrideElements,
    size_t destinationWidth,
    size_t destinationHeight
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(sourceWidth != 0);
    assert(sourceHeight != 0);
    assert(destinationWidth != 0);
    assert(destinationHeight != 0);

    auto sourceRow = sourceBase;

    foreach (sourceY; 0 .. sourceHeight)
    {
        auto sourceSample = sourceRow;

        foreach (sourceX; 0 .. sourceWidth)
        {
            const sourceAddress =
                cast(size_t) sourceSample;

            auto destinationRow =
                destinationBase;

            foreach (destinationY; 0 .. destinationHeight)
            {
                auto destinationSample =
                    destinationRow;

                foreach (destinationX; 0 .. destinationWidth)
                {
                    const destinationAddress =
                        cast(size_t) destinationSample;

                    const distance =
                        sourceAddress <= destinationAddress
                        ? destinationAddress - sourceAddress
                        : sourceAddress - destinationAddress;

                    if (distance < T.sizeof)
                        return true;

                    if (destinationX + 1 < destinationWidth)
                        destinationSample += destinationSampleStrideElements;
                }

                if (destinationY + 1 < destinationHeight)
                    destinationRow += destinationRowStrideElements;
            }

            if (sourceX + 1 < sourceWidth)
                sourceSample += sourceSampleStrideElements;
        }

        if (sourceY + 1 < sourceHeight)
            sourceRow += sourceRowStrideElements;
    }

    return false;
}


/++
    Executes one already-approved Canonical fixed-shape operation.

    Both source and destination sample strides are one.

    The requiredSource base is the top-left sample of the complete halo-expanded
    source rectangle. Therefore each output coordinate (x,y) owns a fixed
    Shape.width x Shape.height window beginning at requiredSource(x,y).
+/
private
void executeCanonicalNeighbourhood(
    alias Shape,
    alias kernel,
    T
)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,

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

    foreach (y; 0 .. height)
    {
        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y * destinationRowStride;

        foreach (x; 0 .. width)
        {
            T[Shape.sampleCount] neighbourhood;
            size_t index;

            foreach (dy; 0 .. Shape.height)
            {
                const sourceRow =
                    sourceBase
                    + cast(ptrdiff_t)(y + dy)
                        * sourceRowStride
                    + cast(ptrdiff_t) x;

                foreach (dx; 0 .. Shape.width)
                {
                    neighbourhood[index++] =
                        sourceRow[dx];
                }
            }

            destinationRow[x] =
                invokeNeighbourhoodKernel!(
                    Shape,
                    kernel,
                    T
                )(
                    neighbourhood
                );
        }
    }
}


/++
    Executes one already-approved signed-affine fixed-shape operation.

    Source and destination base pointers, row strides and sample strides have
    already passed the public structural validation and overlap checks.

    This executor preserves arbitrary validated signed-affine layouts while
    removing repeated RasterView/WritableRasterView sampling and bounds logic
    from the per-pixel hot loop.
+/
private
void executeAffineNeighbourhood(
    alias Shape,
    alias kernel,
    T
)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,

    size_t width,
    size_t height,

    scope T* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride
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
    assert(sourceSampleStride != 0);
    assert(destinationSampleStride != 0);

    auto sourceOutputRow = sourceBase;
    auto destinationRow = destinationBase;

    foreach (y; 0 .. height)
    {
        auto sourceWindow = sourceOutputRow;
        auto destinationSample = destinationRow;

        foreach (x; 0 .. width)
        {
            T[Shape.sampleCount] neighbourhood;
            size_t index;

            auto sourceWindowRow = sourceWindow;

            foreach (dy; 0 .. Shape.height)
            {
                auto sourceSample = sourceWindowRow;

                foreach (dx; 0 .. Shape.width)
                {
                    neighbourhood[index++] = *sourceSample;
                    sourceSample += sourceSampleStride;
                }

                sourceWindowRow += sourceRowStride;
            }

            *destinationSample =
                invokeNeighbourhoodKernel!(
                    Shape,
                    kernel,
                    T
                )(
                    neighbourhood
                );

            sourceWindow += sourceSampleStride;
            destinationSample += destinationSampleStride;
        }

        sourceOutputRow += sourceRowStride;
        destinationRow += destinationRowStride;
    }
}


/++
    Applies one compile-time fixed neighbourhood shape and kernel into a
    caller-owned destination.

    Shape is expected to be one NeighbourhoodShape instantiation.

    sourceOutputRegion is resident-relative to source.

    For non-empty output, source must contain the complete neighbourhood margins
    derived from Shape:

        left   = Shape.left
        right  = Shape.right
        top    = Shape.top
        bottom = Shape.bottom

    Destination width/height must equal sourceOutputRegion width/height.

    Kernel receives Shape.sampleCount values in row-major neighbourhood order.
    Shape.anchorX/anchorY identify the output sample position inside that order.

    Matching empty output succeeds without requiring halo and without invoking
    kernel.

    Structural failures occur before the first destination write.

    Every validated resident signed-affine layout remains supported.

    No border policy is implied. Missing halo is
    RasterNeighbourhoodError.unsatisfiedNeighbourhood.

    No allocation, retained ownership or scheduling occurs.
+/
bool applyNeighbourhoodInto(
    alias Shape,
    alias kernel,
    T
)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterNeighbourhoodError error
)
@safe
nothrow
@nogc
{
    static assert(
        __traits(hasMember, Shape, "width")
        && __traits(hasMember, Shape, "height")
        && __traits(hasMember, Shape, "anchorX")
        && __traits(hasMember, Shape, "anchorY")
        && __traits(hasMember, Shape, "left")
        && __traits(hasMember, Shape, "right")
        && __traits(hasMember, Shape, "top")
        && __traits(hasMember, Shape, "bottom")
        && __traits(hasMember, Shape, "sampleCount"),
        "Shape must provide fixed neighbourhood geometry."
    );

    static assert(
        Shape.width != 0
        && Shape.height != 0
        && Shape.sampleCount
            == Shape.width * Shape.height,
        "Invalid fixed neighbourhood geometry."
    );

    /*
     * Preserve the already-qualified 3 x 3 production path exactly.
     */
    static if (
        Shape.width == 3
        && Shape.height == 3
        && Shape.anchorX == 1
        && Shape.anchorY == 1
        && Shape.sampleCount == 9
    )
    {
        RasterNeighbourhood3x3Error legacyError;

        const ok =
            tryApplyRasterNeighbourhood3x3!kernel(
                source,
                sourcePlaneIndex,
                sourceOutputRegion,
                destination,
                destinationPlaneIndex,
                legacyError
            );

        final switch (legacyError)
        {
            case RasterNeighbourhood3x3Error.none:
                error = RasterNeighbourhoodError.none;
                return ok;

            case RasterNeighbourhood3x3Error.invalidSourcePlane:
                error = RasterNeighbourhoodError.invalidSourcePlane;
                return false;

            case RasterNeighbourhood3x3Error.invalidDestinationPlane:
                error = RasterNeighbourhoodError.invalidDestinationPlane;
                return false;

            case RasterNeighbourhood3x3Error.destinationShapeMismatch:
                error = RasterNeighbourhoodError.destinationShapeMismatch;
                return false;

            case RasterNeighbourhood3x3Error.unsatisfiedNeighbourhood:
                error = RasterNeighbourhoodError.unsatisfiedNeighbourhood;
                return false;

            case RasterNeighbourhood3x3Error.nonInjectiveDestination:
                error = RasterNeighbourhoodError.nonInjectiveDestination;
                return false;

            case RasterNeighbourhood3x3Error.sourceDestinationOverlap:
                error = RasterNeighbourhoodError.sourceDestinationOverlap;
                return false;
        }
    }
    else
    {
        error =
            RasterNeighbourhoodError.none;

        ptrdiff_t sourceRowStrideElements;
        ptrdiff_t sourceSampleStrideElements;

        if (
            !source.tryExecutionPlaneStrides(
                sourcePlaneIndex,
                sourceRowStrideElements,
                sourceSampleStrideElements
            )
        )
        {
            error =
                RasterNeighbourhoodError.invalidSourcePlane;

            return false;
        }

        ptrdiff_t destinationRowStrideElements;
        ptrdiff_t destinationSampleStrideElements;

        if (
            !destination.tryExecutionPlaneStrides(
                destinationPlaneIndex,
                destinationRowStrideElements,
                destinationSampleStrideElements
            )
        )
        {
            error =
                RasterNeighbourhoodError.invalidDestinationPlane;

            return false;
        }

        if (
            destination.width
                != sourceOutputRegion.width
            || destination.height
                != sourceOutputRegion.height
        )
        {
            error =
                RasterNeighbourhoodError.destinationShapeMismatch;

            return false;
        }

        if (
            !source.region.containsRelative(
                sourceOutputRegion
            )
        )
        {
            error =
                RasterNeighbourhoodError.unsatisfiedNeighbourhood;

            return false;
        }

        if (sourceOutputRegion.empty)
            return true;

        const sourceRight =
            source.width
            - sourceOutputRegion.x
            - sourceOutputRegion.width;

        const sourceBottom =
            source.height
            - sourceOutputRegion.y
            - sourceOutputRegion.height;

        if (
            sourceOutputRegion.x < Shape.left
            || sourceOutputRegion.y < Shape.top
            || sourceRight < Shape.right
            || sourceBottom < Shape.bottom
        )
        {
            error =
                RasterNeighbourhoodError.unsatisfiedNeighbourhood;

            return false;
        }

        if (
            !affine2DMappingIsInjective(
                destination.width,
                destination.height,
                destinationRowStrideElements,
                destinationSampleStrideElements
            )
        )
        {
            error =
                RasterNeighbourhoodError.nonInjectiveDestination;

            return false;
        }

        const requiredSourceRelative =
            Region2D(
                sourceOutputRegion.x
                    - Shape.left,
                sourceOutputRegion.y
                    - Shape.top,
                Shape.left
                    + sourceOutputRegion.width
                    + Shape.right,
                Shape.top
                    + sourceOutputRegion.height
                    + Shape.bottom
            );

        bool requiredSourceOk;

        scope auto requiredSource =
            source.tryRoi(
                requiredSourceRelative,
                requiredSourceOk
            );

        assert(requiredSourceOk);

        ptrdiff_t requiredSourceRowStrideElements;
        ptrdiff_t requiredSourceSampleStrideElements;

        const requiredSourceStridesOk =
            requiredSource.tryExecutionPlaneStrides(
                sourcePlaneIndex,
                requiredSourceRowStrideElements,
                requiredSourceSampleStrideElements
            );

        assert(requiredSourceStridesOk);

        const sourceBase =
            requiredSource.executionRegionBase(
                sourcePlaneIndex
            );

        auto destinationBase =
            destination.executionRegionBase(
                destinationPlaneIndex
            );

        assert(sourceBase !is null);
        assert(destinationBase !is null);

        final switch (
            classifyValidatedSameTypeAffine2DRectanglesByteOverlap(
                requiredSource.width,
                requiredSource.height,
                cast(size_t) sourceBase,
                requiredSourceRowStrideElements,
                requiredSourceSampleStrideElements,

                destination.width,
                destination.height,
                cast(size_t) destinationBase,
                destinationRowStrideElements,
                destinationSampleStrideElements,

                T.sizeof
            )
        )
        {
            case AffineByteOverlapRelation.overlap:
                error =
                    RasterNeighbourhoodError.sourceDestinationOverlap;

                return false;

            case AffineByteOverlapRelation.disjoint:
                break;

            case AffineByteOverlapRelation.arithmeticFailure:
                if (
                    asymmetricSampleBytesOverlapFallback(
                        sourceBase,
                        requiredSourceRowStrideElements,
                        requiredSourceSampleStrideElements,
                        requiredSource.width,
                        requiredSource.height,

                        destinationBase,
                        destinationRowStrideElements,
                        destinationSampleStrideElements,
                        destination.width,
                        destination.height
                    )
                )
                {
                    error =
                        RasterNeighbourhoodError.sourceDestinationOverlap;

                    return false;
                }

                break;
        }

        if (
            requiredSourceSampleStrideElements == 1
            && destinationSampleStrideElements == 1
        )
        {
            executeCanonicalNeighbourhood!(
                Shape,
                kernel,
                T
            )(
                sourceBase,
                requiredSourceRowStrideElements,
                destination.width,
                destination.height,
                destinationBase,
                destinationRowStrideElements
            );

            return true;
        }

        /*
         * Validated signed-affine fallback.
         *
         * The semantic layer has already proved the complete required source
         * rectangle reachable, the destination injective and both sample-byte
         * sets disjoint. Carry those facts into one pointer/stride executor
         * rather than re-running view sampling and bounds checks per tap.
         */
        executeAffineNeighbourhood!(
            Shape,
            kernel,
            T
        )(
            sourceBase,
            requiredSourceRowStrideElements,
            requiredSourceSampleStrideElements,

            destination.width,
            destination.height,

            destinationBase,
            destinationRowStrideElements,
            destinationSampleStrideElements
        );

        return true;
    }
}


/// Example reporting an invalid source plane through the generic family.
@safe unittest
{
    import raster;

    alias Shape =
        NeighbourhoodShape!(
            5,
            3,
            2,
            1
        );

    alias center =
        (ref const(float)[15] values)
        @safe pure nothrow @nogc
        => values[7];

    RasterView!float source;
    WritableRasterView!float destination;

    RasterNeighbourhoodError error;

    assert(
        !source.applyNeighbourhoodInto!(
            Shape,
            center
        )(
            0,
            Region2D(0, 0, 1, 1),
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterNeighbourhoodError.invalidSourcePlane
    );
}


version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.neighbourhood_shape :
    NeighbourhoodShape;

import raster.resource :
    ResourceAccess,
    ResourceEntry;

import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import raster.view :
    makeRasterViewAssumeValidated;

import raster.writable_view :
    tryMakeWritableRasterView;


private
WritableRasterView!T makeWritableGenericNeighbourhoodTestView(T)(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!T(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


alias Shape5x3 =
    NeighbourhoodShape!(
        5,
        3,
        2,
        1
    );


@safe
pure
nothrow
@nogc
private
ubyte weighted5x3(
    ref const(ubyte)[15] values
)
{
    uint total;

    foreach (index, value; values)
    {
        total +=
            cast(uint) value
            * cast(uint)(index + 1);
    }

    return cast(ubyte)(total % 251);
}


@safe
pure
nothrow
@nogc
private
ubyte logicalValue(
    size_t x,
    size_t y
)
{
    return cast(ubyte)(
        (
            x * 17
            + y * 29
            + (x ^ y) * 3
        )
        % 251
    );
}


@safe
pure
nothrow
@nogc
private
ubyte oracle5x3(
    size_t centerX,
    size_t centerY
)
{
    ubyte[15] values;
    size_t index;

    foreach (dy; 0 .. Shape5x3.height)
    {
        foreach (dx; 0 .. Shape5x3.width)
        {
            values[index++] =
                logicalValue(
                    centerX + dx
                        - Shape5x3.anchorX,
                    centerY + dy
                        - Shape5x3.anchorY
                );
        }
    }

    return weighted5x3(values);
}


/*
 * Generic 5 x 3 Canonical execution.
 */
unittest
{
    enum size_t sourceWidth = 9;
    enum size_t sourceHeight = 7;
    enum size_t outputWidth = 5;
    enum size_t outputHeight = 5;

    ubyte[sourceWidth * sourceHeight] sourceStorage;

    foreach (y; 0 .. sourceHeight)
        foreach (x; 0 .. sourceWidth)
            sourceStorage[y * sourceWidth + x] =
                logicalValue(x, y);

    ubyte[outputWidth * outputHeight] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            sourceWidth,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            outputWidth,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(
                0,
                0,
                sourceWidth,
                sourceHeight
            )
        );

    scope auto destination =
        makeWritableGenericNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(
                0,
                0,
                outputWidth,
                outputHeight
            )
        );

    RasterNeighbourhoodError error;

    assert(
        source.applyNeighbourhoodInto!(
            Shape5x3,
            weighted5x3
        )(
            0,
            Region2D(
                Shape5x3.left,
                Shape5x3.top,
                outputWidth,
                outputHeight
            ),
            destination,
            0,
            error
        )
    );

    assert(error == RasterNeighbourhoodError.none);

    foreach (y; 0 .. outputHeight)
    {
        foreach (x; 0 .. outputWidth)
        {
            assert(
                destinationStorage[
                    y * outputWidth + x
                ]
                == oracle5x3(
                    x + Shape5x3.anchorX,
                    y + Shape5x3.anchorY
                )
            );
        }
    }
}


/*
 * Generic signed-stride source and destination remain layout-equivalent.
 */
unittest
{
    ubyte[15] sourceStorage;

    foreach (i; 0 .. sourceStorage.length)
        sourceStorage[i] = cast(ubyte)(i + 1);

    ubyte[1] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr + 14,
            -5,
            -1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            1,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 5, 3)
        );

    scope auto destination =
        makeWritableGenericNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    RasterNeighbourhoodError error;

    assert(
        source.applyNeighbourhoodInto!(
            Shape5x3,
            weighted5x3
        )(
            0,
            Region2D(
                Shape5x3.anchorX,
                Shape5x3.anchorY,
                1,
                1
            ),
            destination,
            0,
            error
        )
    );

    assert(error == RasterNeighbourhoodError.none);

    ubyte[15] values;
    size_t index;

    foreach (dy; 0 .. 3)
        foreach (dx; 0 .. 5)
            values[index++] =
                sourceStorage[
                    (2 - dy) * 5
                    + (4 - dx)
                ];

    assert(
        destinationStorage[0]
        == weighted5x3(values)
    );
}


/*
 * Structural halo failure occurs before destination write.
 */
unittest
{
    ubyte[15] sourceStorage;
    ubyte[1] destinationStorage = [77];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            5,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            1,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 5, 3)
        );

    scope auto destination =
        makeWritableGenericNeighbourhoodTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    RasterNeighbourhoodError error;

    assert(
        !source.applyNeighbourhoodInto!(
            Shape5x3,
            weighted5x3
        )(
            0,
            Region2D(1, 1, 1, 1),
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterNeighbourhoodError.unsatisfiedNeighbourhood
    );

    assert(destinationStorage[0] == 77);
}


/*
 * Whole-vs-streamed 5 x 3 execution reassembles exactly.
 */
unittest
{
    enum size_t sourceWidth = 9;
    enum size_t sourceHeight = 7;
    enum size_t outputWidth = 5;
    enum size_t outputHeight = 5;

    ubyte[sourceWidth * sourceHeight] wholeSourceStorage;

    foreach (y; 0 .. sourceHeight)
        foreach (x; 0 .. sourceWidth)
            wholeSourceStorage[y * sourceWidth + x] =
                logicalValue(x, y);

    ubyte[outputWidth * outputHeight] wholeOutput;

    const PlaneDescriptor[1] wholeSourceDescriptors =
    [
        PlaneDescriptor(
            wholeSourceStorage.ptr,
            sourceWidth,
            1
        )
    ];

    const PlaneDescriptor[1] wholeOutputDescriptors =
    [
        PlaneDescriptor(
            wholeOutput.ptr,
            outputWidth,
            1
        )
    ];

    const ResourceEntry[1] wholeOutputResources =
    [
        ResourceEntry(
            wholeOutput.ptr,
            wholeOutput.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto wholeSource =
        makeRasterViewAssumeValidated!ubyte(
            wholeSourceDescriptors[],
            Region2D(
                0,
                0,
                sourceWidth,
                sourceHeight
            )
        );

    scope auto wholeDestination =
        makeWritableGenericNeighbourhoodTestView!ubyte(
            wholeOutputResources[],
            wholeOutputDescriptors[],
            Region2D(
                0,
                0,
                outputWidth,
                outputHeight
            )
        );

    RasterNeighbourhoodError error;

    assert(
        wholeSource.applyNeighbourhoodInto!(
            Shape5x3,
            weighted5x3
        )(
            0,
            Region2D(
                Shape5x3.left,
                Shape5x3.top,
                outputWidth,
                outputHeight
            ),
            wholeDestination,
            0,
            error
        )
    );

    ubyte[outputWidth * outputHeight] streamed;

    foreach (taskIndex; 0 .. 2)
    {
        const outputY =
            taskIndex == 0
            ? 0
            : 2;

        const taskHeight =
            taskIndex == 0
            ? 2
            : 3;

        const residentHeight =
            Shape5x3.top
            + taskHeight
            + Shape5x3.bottom;

        ubyte[sourceWidth * 5] taskSourceStorage;
        ubyte[outputWidth * 3] taskOutputStorage;

        foreach (residentY; 0 .. residentHeight)
        {
            foreach (x; 0 .. sourceWidth)
            {
                taskSourceStorage[
                    residentY * sourceWidth + x
                ] =
                    logicalValue(
                        x,
                        outputY + residentY
                    );
            }
        }

        const PlaneDescriptor[1] taskSourceDescriptors =
        [
            PlaneDescriptor(
                taskSourceStorage.ptr,
                sourceWidth,
                1
            )
        ];

        const PlaneDescriptor[1] taskOutputDescriptors =
        [
            PlaneDescriptor(
                taskOutputStorage.ptr,
                outputWidth,
                1
            )
        ];

        const ResourceEntry[1] taskOutputResources =
        [
            ResourceEntry(
                taskOutputStorage.ptr,
                taskOutputStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto taskSource =
            makeRasterViewAssumeValidated!ubyte(
                taskSourceDescriptors[],
                Region2D(
                    0,
                    0,
                    sourceWidth,
                    residentHeight
                )
            );

        scope auto taskDestination =
            makeWritableGenericNeighbourhoodTestView!ubyte(
                taskOutputResources[],
                taskOutputDescriptors[],
                Region2D(
                    0,
                    0,
                    outputWidth,
                    taskHeight
                )
            );

        assert(
            taskSource.applyNeighbourhoodInto!(
                Shape5x3,
                weighted5x3
            )(
                0,
                Region2D(
                    Shape5x3.left,
                    Shape5x3.top,
                    outputWidth,
                    taskHeight
                ),
                taskDestination,
                0,
                error
            )
        );

        foreach (y; 0 .. taskHeight)
        {
            foreach (x; 0 .. outputWidth)
            {
                streamed[
                    (outputY + y)
                        * outputWidth
                    + x
                ] =
                    taskOutputStorage[
                        y * outputWidth + x
                    ];
            }
        }
    }

    assert(streamed == wholeOutput);
}

} // version (unittest)
