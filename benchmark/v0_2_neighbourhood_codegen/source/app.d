module raster.benchmark_neighbourhood_codegen;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective;

import raster.internal.neighbourhood_dispatch :
    executeApprovedNeighbourhood3x3;

import raster.internal.validated_affine_relation :
    classifyValidatedSameTypeAffine2DRectanglesByteOverlap;


private enum size_t warmups = 6;
private enum size_t samples = 18;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private float weighted3x3(ref const(float)[9] values)
@safe pure nothrow @nogc
{
    float total = 0.0f;

    static foreach (i; 0 .. 9)
        total += values[i] * cast(float)(i + 1) * 0.03125f;

    return total;
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPadding,
    bool sourcePattern,
    ref RasterLease!float lease
)
@system
{
    const rowElements = width + rowPadding;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const count = rowElements * height;

    if (count > size_t.max / float.sizeof)
        return false;

    void* memory = malloc(count * float.sizeof);

    if (memory is null)
        return false;

    auto data = (cast(float*) memory)[0 .. count];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            if (sourcePattern && x < width)
            {
                data[y * rowElements + x] =
                    cast(float)(
                        cast(int)((y * 131 + x * 17 + 23) % 509)
                        - 254
                    ) * 0.015625f;
            }
            else
            {
                data[y * rowElements + x] = -9999.0f;
            }
        }
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(memory, count * float.sizeof, resource))
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    return tryImportOwnedRaster!float(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    ).ok;
}


private ulong checksum(scope RasterView!float view)
@safe
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. view.height)
    {
        foreach (x; 0 .. view.width)
        {
            float value;
            require(view.trySample(0, x, y, value), "checksum read failed");

            union Bits
            {
                float value;
                uint bits;
            }

            Bits bits;
            bits.value = value;

            hash ^= bits.bits;
            hash *= 1099511628211UL;
        }
    }

    return hash;
}


private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
}


private string compilerName()
{
    version (DigitalMars)
        return "dmd";
    else version (LDC)
        return "ldc";
    else
        return "other";
}


private struct Approved3x3
{
    scope const(float)* sourceBase;
    ptrdiff_t sourceRowStride;
    float* destinationBase;
    ptrdiff_t destinationRowStride;
}


pragma(inline, false)
private Approved3x3 diagnosticPreflight(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height
)
@safe
{
    ptrdiff_t sourceRowStride;
    ptrdiff_t sourceSampleStride;
    ptrdiff_t destinationRowStride;
    ptrdiff_t destinationSampleStride;

    require(
        source.tryExecutionPlaneStrides(
            0,
            sourceRowStride,
            sourceSampleStride
        ),
        "source stride unavailable"
    );

    require(
        destination.tryExecutionPlaneStrides(
            0,
            destinationRowStride,
            destinationSampleStride
        ),
        "destination stride unavailable"
    );

    require(
        sourceSampleStride == 1
        && destinationSampleStride == 1,
        "diagnostic requires Canonical sample strides"
    );

    require(
        destination.width == width
        && destination.height == height,
        "destination shape mismatch"
    );

    const outputRegion = Region2D(1, 1, width, height);

    require(
        source.region.containsRelative(outputRegion),
        "output region outside source"
    );

    require(
        outputRegion.x != 0
        && outputRegion.y != 0
        && outputRegion.width < source.width - outputRegion.x
        && outputRegion.height < source.height - outputRegion.y,
        "3x3 halo missing"
    );

    require(
        affine2DMappingIsInjective(
            destination.width,
            destination.height,
            destinationRowStride,
            destinationSampleStride
        ),
        "destination not injective"
    );

    bool roiOk;
    scope auto requiredSource =
        source.tryRoi(
            Region2D(
                outputRegion.x - 1,
                outputRegion.y - 1,
                outputRegion.width + 2,
                outputRegion.height + 2
            ),
            roiOk
        );

    require(roiOk, "required source ROI failed");

    ptrdiff_t requiredRowStride;
    ptrdiff_t requiredSampleStride;

    require(
        requiredSource.tryExecutionPlaneStrides(
            0,
            requiredRowStride,
            requiredSampleStride
        ),
        "required source stride unavailable"
    );

    const sourceBase =
        requiredSource.executionRegionBase(0);

    auto destinationBase =
        destination.executionRegionBase(0);

    require(
        sourceBase !is null
        && destinationBase !is null,
        "execution base unavailable"
    );

    const relation =
        classifyValidatedSameTypeAffine2DRectanglesByteOverlap(
            requiredSource.width,
            requiredSource.height,
            cast(size_t) sourceBase,
            requiredRowStride,
            requiredSampleStride,
            destination.width,
            destination.height,
            cast(size_t) destinationBase,
            destinationRowStride,
            destinationSampleStride,
            float.sizeof
        );

    require(
        relation == AffineByteOverlapRelation.disjoint,
        "diagnostic requires proven disjoint backing"
    );

    Approved3x3 result;
    result.sourceBase = sourceBase;
    result.sourceRowStride = requiredRowStride;
    result.destinationBase = destinationBase;
    result.destinationRowStride = destinationRowStride;
    return result;
}


pragma(inline, false)
private void executeHotNoInline(
    Approved3x3 approved,
    size_t width,
    size_t height
)
@safe pure nothrow @nogc
{
    executeApprovedNeighbourhood3x3!weighted3x3(
        approved.sourceBase,
        approved.sourceRowStride,
        1,
        1,
        width,
        height,
        approved.destinationBase,
        approved.destinationRowStride
    );
}


private long timePublic(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterNeighbourhood3x3Error error;

        require(
            tryApplyRasterNeighbourhood3x3!weighted3x3(
                source,
                0,
                Region2D(1, 1, width, height),
                destination,
                0,
                error
            ),
            "public neighbourhood failed"
        );

        require(
            error == RasterNeighbourhood3x3Error.none,
            "public neighbourhood error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeHotDirect(
    Approved3x3 approved,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        executeApprovedNeighbourhood3x3!weighted3x3(
            approved.sourceBase,
            approved.sourceRowStride,
            1,
            1,
            width,
            height,
            approved.destinationBase,
            approved.destinationRowStride
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeHotNoInline(
    Approved3x3 approved,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        executeHotNoInline(approved, width, height);

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timePreflightNoInlineHot(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        const approved =
            diagnosticPreflight(source, destination, width, height);

        executeHotNoInline(approved, width, height);
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timePreflightOnly(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations,
    out ulong sink
)
@safe
{
    sink = 0;

    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const approved =
            diagnosticPreflight(source, destination, width, height);

        sink ^=
            cast(ulong) cast(size_t) approved.sourceBase
            ^ cast(ulong) cast(size_t) approved.destinationBase
            ^ cast(ulong) approved.sourceRowStride
            ^ cast(ulong) approved.destinationRowStride
            ^ cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private void emit(
    string path,
    size_t width,
    size_t height,
    size_t iterations,
    long medianNs,
    ulong resultChecksum
)
{
    const pixels =
        cast(double)(width * height * iterations);

    writefln(
        "neighbourhood_codegen compiler=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        path,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / pixels,
        resultChecksum
    );
}


void main(string[] args)
@system
{
    const width =
        args.length >= 2 ? args[1].to!size_t : 1024;

    const height =
        args.length >= 3 ? args[2].to!size_t : 512;

    const iterations =
        args.length >= 4 ? args[3].to!size_t : 8;

    RasterLease!float sourceLease;
    RasterLease!float destinationLease;

    require(
        makeFloatLease(
            width + 2,
            height + 2,
            32,
            true,
            sourceLease
        ),
        "source construction failed"
    );

    require(
        makeFloatLease(
            width,
            height,
            0,
            false,
            destinationLease
        ),
        "destination construction failed"
    );

    scope auto source = sourceLease.view();

    bool writableOk;
    scope auto destination =
        destinationLease.tryWritableView(writableOk);

    require(writableOk, "destination writable view failed");

    const approved =
        diagnosticPreflight(source, destination, width, height);

    // Semantic preflight for all executing paths.
    timePublic(source, destination, width, height, 1);
    const publicChecksum = checksum(destinationLease.view());

    timeHotDirect(approved, width, height, 1);
    require(
        checksum(destinationLease.view()) == publicChecksum,
        "direct hot output mismatch"
    );

    timeHotNoInline(approved, width, height, 1);
    require(
        checksum(destinationLease.view()) == publicChecksum,
        "noinline hot output mismatch"
    );

    timePreflightNoInlineHot(
        source,
        destination,
        width,
        height,
        1
    );

    require(
        checksum(destinationLease.view()) == publicChecksum,
        "preflight+noinline output mismatch"
    );

    ulong ignoredSink;

    foreach (_; 0 .. warmups)
    {
        timePublic(source, destination, width, height, 1);
        timeHotDirect(approved, width, height, 1);
        timeHotNoInline(approved, width, height, 1);
        timePreflightNoInlineHot(source, destination, width, height, 1);
        timePreflightOnly(source, destination, width, height, 1, ignoredSink);
    }

    long[samples] publicTimes;
    long[samples] hotDirectTimes;
    long[samples] hotNoInlineTimes;
    long[samples] preflightHotTimes;
    long[samples] preflightOnlyTimes;

    ulong sink;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 5)
        {
            case 0:
                publicTimes[sample] = timePublic(source, destination, width, height, iterations);
                hotDirectTimes[sample] = timeHotDirect(approved, width, height, iterations);
                hotNoInlineTimes[sample] = timeHotNoInline(approved, width, height, iterations);
                preflightHotTimes[sample] = timePreflightNoInlineHot(source, destination, width, height, iterations);
                preflightOnlyTimes[sample] = timePreflightOnly(source, destination, width, height, iterations, sink);
                break;
            case 1:
                hotDirectTimes[sample] = timeHotDirect(approved, width, height, iterations);
                preflightOnlyTimes[sample] = timePreflightOnly(source, destination, width, height, iterations, sink);
                publicTimes[sample] = timePublic(source, destination, width, height, iterations);
                preflightHotTimes[sample] = timePreflightNoInlineHot(source, destination, width, height, iterations);
                hotNoInlineTimes[sample] = timeHotNoInline(approved, width, height, iterations);
                break;
            case 2:
                hotNoInlineTimes[sample] = timeHotNoInline(approved, width, height, iterations);
                publicTimes[sample] = timePublic(source, destination, width, height, iterations);
                preflightHotTimes[sample] = timePreflightNoInlineHot(source, destination, width, height, iterations);
                hotDirectTimes[sample] = timeHotDirect(approved, width, height, iterations);
                preflightOnlyTimes[sample] = timePreflightOnly(source, destination, width, height, iterations, sink);
                break;
            case 3:
                preflightHotTimes[sample] = timePreflightNoInlineHot(source, destination, width, height, iterations);
                hotNoInlineTimes[sample] = timeHotNoInline(approved, width, height, iterations);
                preflightOnlyTimes[sample] = timePreflightOnly(source, destination, width, height, iterations, sink);
                hotDirectTimes[sample] = timeHotDirect(approved, width, height, iterations);
                publicTimes[sample] = timePublic(source, destination, width, height, iterations);
                break;
            case 4:
                preflightOnlyTimes[sample] = timePreflightOnly(source, destination, width, height, iterations, sink);
                preflightHotTimes[sample] = timePreflightNoInlineHot(source, destination, width, height, iterations);
                hotDirectTimes[sample] = timeHotDirect(approved, width, height, iterations);
                publicTimes[sample] = timePublic(source, destination, width, height, iterations);
                hotNoInlineTimes[sample] = timeHotNoInline(approved, width, height, iterations);
                break;
        }
    }

    const publicMedian = median(publicTimes);
    const hotDirectMedian = median(hotDirectTimes);
    const hotNoInlineMedian = median(hotNoInlineTimes);
    const preflightHotMedian = median(preflightHotTimes);
    const preflightOnlyMedian = median(preflightOnlyTimes);

    require(
        checksum(destinationLease.view()) == publicChecksum,
        "timed output mismatch"
    );

    emit("public", width, height, iterations, publicMedian, publicChecksum);
    emit("hot_direct", width, height, iterations, hotDirectMedian, publicChecksum);
    emit("hot_noinline", width, height, iterations, hotNoInlineMedian, publicChecksum);
    emit("preflight_noinline_hot", width, height, iterations, preflightHotMedian, publicChecksum);

    writefln(
        "neighbourhood_codegen_preflight compiler=%s iterations=%s samples=%s median_ns_per_call=%.3f sink=%016x",
        compilerName(),
        iterations,
        samples,
        cast(double) preflightOnlyMedian / cast(double) iterations,
        sink
    );

    writefln(
        "neighbourhood_codegen_ratio compiler=%s public_over_hot_direct=%.6f public_over_preflight_noinline_hot=%.6f hot_noinline_over_hot_direct=%.6f preflight_noinline_hot_over_hot_noinline=%.6f",
        compilerName(),
        cast(double) publicMedian / cast(double) hotDirectMedian,
        cast(double) publicMedian / cast(double) preflightHotMedian,
        cast(double) hotNoInlineMedian / cast(double) hotDirectMedian,
        cast(double) preflightHotMedian / cast(double) hotNoInlineMedian
    );
}
