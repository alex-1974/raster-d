module raster.benchmark_neighbourhood_family;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;

import raster.internal.neighbourhood_dispatch :
    executeApprovedNeighbourhood3x3;


private enum size_t warmups = 6;
private enum size_t samples = 18;


alias Shape3x3 =
    NeighbourhoodShape!(3, 3, 1, 1);

alias Shape5x3 =
    NeighbourhoodShape!(5, 3, 2, 1);


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private float weighted3x3(
    ref const(float)[9] values
)
@safe
pure
nothrow
@nogc
{
    float total = 0.0f;

    static foreach (i; 0 .. 9)
    {
        total +=
            values[i]
            * cast(float)(i + 1)
            * 0.03125f;
    }

    return total;
}


private float weighted5x3(
    ref const(float)[15] values
)
@safe
pure
nothrow
@nogc
{
    float total = 0.0f;

    static foreach (i; 0 .. 15)
    {
        total +=
            values[i]
            * cast(float)(i + 1)
            * 0.015625f;
    }

    return total;
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t sampleStep,
    size_t rowPaddingElements,
    bool sourcePattern,
    ref RasterLease!float lease
)
@system
{
    if (
        width == 0
        || height == 0
        || sampleStep == 0
        || width > (size_t.max - rowPaddingElements) / sampleStep
    )
        return false;

    const rowElements =
        width * sampleStep
        + rowPaddingElements;

    if (rowElements > size_t.max / height)
        return false;

    const physicalElements =
        rowElements * height;

    if (physicalElements > size_t.max / float.sizeof)
        return false;

    const byteLength =
        physicalElements * float.sizeof;

    void* memory = malloc(byteLength);

    if (memory is null)
        return false;

    auto typed =
        (cast(float*) memory)[0 .. physicalElements];

    foreach (i; 0 .. physicalElements)
        typed[i] = -9999.0f;

    if (sourcePattern)
    {
        foreach (y; 0 .. height)
        {
            foreach (x; 0 .. width)
            {
                typed[y * rowElements + x * sampleStep] =
                    cast(float)(
                        cast(int)((y * 131 + x * 17 + 23) % 509)
                        - 254
                    )
                    * 0.015625f;
            }
        }
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            byteLength,
            resource
        )
    )
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t)(sampleStep * float.sizeof)
        )
    ];

    const imported =
        tryImportOwnedRaster!float(
            resource,
            layouts[],
            Region2D(0, 0, width, height),
            lease
        );

    return imported.ok;
}


private ulong checksum(
    scope RasterView!float view
)
@safe
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. view.height)
    {
        foreach (x; 0 .. view.width)
        {
            float value;

            require(
                view.trySample(0, x, y, value),
                "checksum sample read failed"
            );

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

    return (
        values[samples / 2 - 1]
        + values[samples / 2]
    ) / 2;
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


private long timeGeneric3x3(
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
        RasterNeighbourhoodError error;

        require(
            source.applyNeighbourhoodInto!(
                Shape3x3,
                weighted3x3
            )(
                0,
                Region2D(1, 1, width, height),
                destination,
                0,
                error
            ),
            "generic 3x3 failed"
        );

        require(
            error == RasterNeighbourhoodError.none,
            "generic 3x3 error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeLegacy3x3(
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
            "legacy 3x3 failed"
        );

        require(
            error == RasterNeighbourhood3x3Error.none,
            "legacy 3x3 error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeHot3x3(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations
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
        "hot source stride unavailable"
    );

    require(
        destination.tryExecutionPlaneStrides(
            0,
            destinationRowStride,
            destinationSampleStride
        ),
        "hot destination stride unavailable"
    );

    require(
        sourceSampleStride == 1
        && destinationSampleStride == 1,
        "hot 3x3 requires Canonical sample strides"
    );

    const sourceBase =
        source.executionRegionBase(0);

    auto destinationBase =
        destination.executionRegionBase(0);

    require(
        sourceBase !is null
        && destinationBase !is null,
        "hot 3x3 base unavailable"
    );

    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        executeApprovedNeighbourhood3x3!weighted3x3(
            sourceBase,
            sourceRowStride,
            1,
            1,
            width,
            height,
            destinationBase,
            destinationRowStride
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeGeneric5x3(
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
        RasterNeighbourhoodError error;

        require(
            source.applyNeighbourhoodInto!(
                Shape5x3,
                weighted5x3
            )(
                0,
                Region2D(2, 1, width, height),
                destination,
                0,
                error
            ),
            "generic 5x3 failed"
        );

        require(
            error == RasterNeighbourhoodError.none,
            "generic 5x3 error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private void emit(
    string operation,
    string path,
    size_t width,
    size_t height,
    size_t iterations,
    long medianNs,
    ulong resultChecksum
)
{
    const logicalSamples =
        cast(double)(width * height * iterations);

    writefln(
        "neighbourhood_benchmark compiler=%s operation=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(),
        operation,
        path,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / logicalSamples,
        resultChecksum
    );
}


void main(string[] args)
@system
{
    const width =
        args.length >= 2
        ? args[1].to!size_t
        : 1024;

    const height =
        args.length >= 3
        ? args[2].to!size_t
        : 512;

    const iterations =
        args.length >= 4
        ? args[3].to!size_t
        : 8;

    enum size_t rowPadding = 32;

    RasterLease!float source3Lease;
    RasterLease!float generic3Lease;
    RasterLease!float legacy3Lease;
    RasterLease!float hot3Lease;

    require(
        makeFloatLease(
            width + 2,
            height + 2,
            1,
            rowPadding,
            true,
            source3Lease
        ),
        "3x3 source construction failed"
    );

    require(
        makeFloatLease(width, height, 1, 0, false, generic3Lease)
        && makeFloatLease(width, height, 1, 0, false, legacy3Lease)
        && makeFloatLease(width, height, 1, 0, false, hot3Lease),
        "3x3 destination construction failed"
    );

    scope auto source3 = source3Lease.view();

    bool generic3Writable;
    bool legacy3Writable;
    bool hot3Writable;

    scope auto generic3 =
        generic3Lease.tryWritableView(generic3Writable);

    scope auto legacy3 =
        legacy3Lease.tryWritableView(legacy3Writable);

    scope auto hot3 =
        hot3Lease.tryWritableView(hot3Writable);

    require(
        generic3Writable
        && legacy3Writable
        && hot3Writable,
        "3x3 writable destination unavailable"
    );

    // Semantic preflight.
    require(
        timeGeneric3x3(source3, generic3, width, height, 1) >= 0,
        "generic 3x3 preflight failed"
    );

    require(
        timeLegacy3x3(source3, legacy3, width, height, 1) >= 0,
        "legacy 3x3 preflight failed"
    );

    require(
        timeHot3x3(source3, hot3, width, height, 1) >= 0,
        "hot 3x3 preflight failed"
    );

    const generic3Checksum = checksum(generic3Lease.view());
    const legacy3Checksum = checksum(legacy3Lease.view());
    const hot3Checksum = checksum(hot3Lease.view());

    require(
        generic3Checksum == legacy3Checksum
        && generic3Checksum == hot3Checksum,
        "3x3 output mismatch"
    );

    RasterLease!float source5CanonicalLease;
    RasterLease!float destination5CanonicalLease;
    RasterLease!float source5StridedLease;
    RasterLease!float destination5StridedLease;

    require(
        makeFloatLease(
            width + 4,
            height + 2,
            1,
            rowPadding,
            true,
            source5CanonicalLease
        )
        && makeFloatLease(
            width,
            height,
            1,
            0,
            false,
            destination5CanonicalLease
        )
        && makeFloatLease(
            width + 4,
            height + 2,
            2,
            rowPadding,
            true,
            source5StridedLease
        )
        && makeFloatLease(
            width,
            height,
            2,
            rowPadding,
            false,
            destination5StridedLease
        ),
        "5x3 lease construction failed"
    );

    scope auto source5Canonical = source5CanonicalLease.view();
    scope auto source5Strided = source5StridedLease.view();

    bool canonical5Writable;
    bool strided5Writable;

    scope auto destination5Canonical =
        destination5CanonicalLease.tryWritableView(
            canonical5Writable
        );

    scope auto destination5Strided =
        destination5StridedLease.tryWritableView(
            strided5Writable
        );

    require(
        canonical5Writable
        && strided5Writable,
        "5x3 writable destination unavailable"
    );

    require(
        timeGeneric5x3(
            source5Canonical,
            destination5Canonical,
            width,
            height,
            1
        ) >= 0,
        "canonical 5x3 preflight failed"
    );

    require(
        timeGeneric5x3(
            source5Strided,
            destination5Strided,
            width,
            height,
            1
        ) >= 0,
        "strided 5x3 preflight failed"
    );

    const canonical5Checksum =
        checksum(destination5CanonicalLease.view());

    const strided5Checksum =
        checksum(destination5StridedLease.view());

    require(
        canonical5Checksum == strided5Checksum,
        "5x3 Canonical/strided output mismatch"
    );


    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 3)
        {
            case 0:
                timeGeneric3x3(source3, generic3, width, height, 1);
                timeLegacy3x3(source3, legacy3, width, height, 1);
                timeHot3x3(source3, hot3, width, height, 1);
                timeGeneric5x3(source5Canonical, destination5Canonical, width, height, 1);
                timeGeneric5x3(source5Strided, destination5Strided, width, height, 1);
                break;

            case 1:
                timeGeneric5x3(source5Strided, destination5Strided, width, height, 1);
                timeGeneric5x3(source5Canonical, destination5Canonical, width, height, 1);
                timeHot3x3(source3, hot3, width, height, 1);
                timeLegacy3x3(source3, legacy3, width, height, 1);
                timeGeneric3x3(source3, generic3, width, height, 1);
                break;

            case 2:
                timeHot3x3(source3, hot3, width, height, 1);
                timeGeneric3x3(source3, generic3, width, height, 1);
                timeGeneric5x3(source5Canonical, destination5Canonical, width, height, 1);
                timeLegacy3x3(source3, legacy3, width, height, 1);
                timeGeneric5x3(source5Strided, destination5Strided, width, height, 1);
                break;
        }
    }

    long[samples] generic3Times;
    long[samples] legacy3Times;
    long[samples] hot3Times;
    long[samples] canonical5Times;
    long[samples] strided5Times;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 5)
        {
            case 0:
                generic3Times[sample] = timeGeneric3x3(source3, generic3, width, height, iterations);
                legacy3Times[sample] = timeLegacy3x3(source3, legacy3, width, height, iterations);
                hot3Times[sample] = timeHot3x3(source3, hot3, width, height, iterations);
                canonical5Times[sample] = timeGeneric5x3(source5Canonical, destination5Canonical, width, height, iterations);
                strided5Times[sample] = timeGeneric5x3(source5Strided, destination5Strided, width, height, iterations);
                break;

            case 1:
                legacy3Times[sample] = timeLegacy3x3(source3, legacy3, width, height, iterations);
                hot3Times[sample] = timeHot3x3(source3, hot3, width, height, iterations);
                canonical5Times[sample] = timeGeneric5x3(source5Canonical, destination5Canonical, width, height, iterations);
                strided5Times[sample] = timeGeneric5x3(source5Strided, destination5Strided, width, height, iterations);
                generic3Times[sample] = timeGeneric3x3(source3, generic3, width, height, iterations);
                break;

            case 2:
                hot3Times[sample] = timeHot3x3(source3, hot3, width, height, iterations);
                strided5Times[sample] = timeGeneric5x3(source5Strided, destination5Strided, width, height, iterations);
                generic3Times[sample] = timeGeneric3x3(source3, generic3, width, height, iterations);
                canonical5Times[sample] = timeGeneric5x3(source5Canonical, destination5Canonical, width, height, iterations);
                legacy3Times[sample] = timeLegacy3x3(source3, legacy3, width, height, iterations);
                break;

            case 3:
                canonical5Times[sample] = timeGeneric5x3(source5Canonical, destination5Canonical, width, height, iterations);
                generic3Times[sample] = timeGeneric3x3(source3, generic3, width, height, iterations);
                strided5Times[sample] = timeGeneric5x3(source5Strided, destination5Strided, width, height, iterations);
                legacy3Times[sample] = timeLegacy3x3(source3, legacy3, width, height, iterations);
                hot3Times[sample] = timeHot3x3(source3, hot3, width, height, iterations);
                break;

            case 4:
                strided5Times[sample] = timeGeneric5x3(source5Strided, destination5Strided, width, height, iterations);
                canonical5Times[sample] = timeGeneric5x3(source5Canonical, destination5Canonical, width, height, iterations);
                legacy3Times[sample] = timeLegacy3x3(source3, legacy3, width, height, iterations);
                hot3Times[sample] = timeHot3x3(source3, hot3, width, height, iterations);
                generic3Times[sample] = timeGeneric3x3(source3, generic3, width, height, iterations);
                break;
        }
    }

    const generic3Median = median(generic3Times);
    const legacy3Median = median(legacy3Times);
    const hot3Median = median(hot3Times);
    const canonical5Median = median(canonical5Times);
    const strided5Median = median(strided5Times);

    // Re-check outputs after timed execution.
    require(
        checksum(generic3Lease.view()) == generic3Checksum
        && checksum(legacy3Lease.view()) == generic3Checksum
        && checksum(hot3Lease.view()) == generic3Checksum,
        "3x3 timed output mismatch"
    );

    require(
        checksum(destination5CanonicalLease.view()) == canonical5Checksum
        && checksum(destination5StridedLease.view()) == canonical5Checksum,
        "5x3 timed output mismatch"
    );

    emit(
        "3x3",
        "public_generic",
        width,
        height,
        iterations,
        generic3Median,
        generic3Checksum
    );

    emit(
        "3x3",
        "public_legacy",
        width,
        height,
        iterations,
        legacy3Median,
        generic3Checksum
    );

    emit(
        "3x3",
        "hot_executor",
        width,
        height,
        iterations,
        hot3Median,
        generic3Checksum
    );

    emit(
        "5x3",
        "public_canonical",
        width,
        height,
        iterations,
        canonical5Median,
        canonical5Checksum
    );

    emit(
        "5x3",
        "public_strided",
        width,
        height,
        iterations,
        strided5Median,
        canonical5Checksum
    );

    writefln(
        "neighbourhood_ratio compiler=%s comparison=generic3_over_legacy3 value=%.6f",
        compilerName(),
        cast(double) generic3Median / cast(double) legacy3Median
    );

    writefln(
        "neighbourhood_ratio compiler=%s comparison=generic3_over_hot3 value=%.6f",
        compilerName(),
        cast(double) generic3Median / cast(double) hot3Median
    );

    writefln(
        "neighbourhood_ratio compiler=%s comparison=legacy3_over_hot3 value=%.6f",
        compilerName(),
        cast(double) legacy3Median / cast(double) hot3Median
    );

    writefln(
        "neighbourhood_ratio compiler=%s comparison=strided5_over_canonical5 value=%.6f",
        compilerName(),
        cast(double) strided5Median / cast(double) canonical5Median
    );
}
