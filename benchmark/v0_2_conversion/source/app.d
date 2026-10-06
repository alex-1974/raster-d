module raster.benchmark_conversion;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;

import std.stdio : writefln;

import raster;

import raster.internal.compact_allocation :
    CompactAllocationError,
    allocateCompactRaster;

import raster.internal.exact_conversion :
    ExactRasterConversionError,
    convertExactRasterPlane;


private enum size_t warmups = 6;
private enum size_t samples = 18;

private enum ubyte ubytePaddingCanary = 0xD7;
private enum ushort ushortPaddingCanary = 0xD7D7;
private enum float floatPaddingCanary = 12345.25f;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private bool makeSourceLease(T)(
    size_t width,
    size_t height,
    size_t rowPadding,
    int seed,
    ref RasterLease!T lease,
    out T* base,
    out size_t rowElements
)
@system
{
    rowElements = width + rowPadding;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const elementCount = rowElements * height;

    if (elementCount > size_t.max / T.sizeof)
        return false;

    void* memory = malloc(elementCount * T.sizeof);

    if (memory is null)
        return false;

    base = cast(T*) memory;

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            if (x >= width)
            {
                static if (is(T == ubyte))
                    base[y * rowElements + x] = ubytePaddingCanary;
                else static if (is(T == ushort))
                    base[y * rowElements + x] = ushortPaddingCanary;
                else
                    static assert(false);
            }
            else
            {
                base[y * rowElements + x] =
                    cast(T)((y * 131 + x * 17 + seed) & T.max);
            }
        }
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(memory, elementCount * T.sizeof, resource))
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * T.sizeof),
            cast(ptrdiff_t) T.sizeof
        )
    ];

    const imported = tryImportOwnedRaster!T(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    );

    return imported.ok;
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPadding,
    ref RasterLease!float lease,
    out float* base,
    out size_t rowElements
)
@system
{
    rowElements = width + rowPadding;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const elementCount = rowElements * height;

    if (elementCount > size_t.max / float.sizeof)
        return false;

    void* memory = malloc(elementCount * float.sizeof);

    if (memory is null)
        return false;

    base = cast(float*) memory;

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            base[y * rowElements + x] =
                x < width ? -1.0f : floatPaddingCanary;
        }
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(
            memory,
            elementCount * float.sizeof,
            resource
        ))
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const imported = tryImportOwnedRaster!float(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    );

    return imported.ok;
}


private ulong checksumFloat(
    scope const(float)* base,
    size_t width,
    size_t height,
    size_t rowElements
)
@trusted nothrow @nogc
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. height)
    {
        const row = base + y * rowElements;

        foreach (x; 0 .. width)
        {
            const bits = *cast(const(uint)*) &row[x];

            hash ^= bits;
            hash *= 1099511628211UL;
        }
    }

    return hash;
}


private bool floatPaddingIsIntact(
    scope const(float)* base,
    size_t width,
    size_t height,
    size_t rowElements
)
@trusted nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const row = base + y * rowElements;

        foreach (x; width .. rowElements)
        {
            if (row[x] != floatPaddingCanary)
                return false;
        }
    }

    return true;
}


private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
}


private long timeUbyteGeneric(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterConversionError error;

        require(
            source.convertRasterInto!float(
                0,
                destination,
                0,
                error
            ),
            "ubyte generic conversion failed"
        );

        require(
            error == RasterConversionError.none,
            "ubyte generic conversion returned error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeUbyteSpecialized(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        UbyteToFloatConversionError error;

        require(
            tryConvertUbyteToFloatPlane(
                source,
                0,
                destination,
                0,
                error
            ),
            "ubyte specialized conversion failed"
        );

        require(
            error == UbyteToFloatConversionError.none,
            "ubyte specialized conversion returned error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeUbyteSemantic(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        require(
            convertExactRasterPlane!(ubyte, float)(
                source,
                0,
                destination,
                0
            ) == ExactRasterConversionError.none,
            "ubyte semantic engine failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeUshortGeneric(
    scope RasterView!ushort source,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterConversionError error;

        require(
            source.convertRasterInto!float(
                0,
                destination,
                0,
                error
            ),
            "ushort generic conversion failed"
        );

        require(
            error == RasterConversionError.none,
            "ushort generic conversion returned error"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeUshortSemantic(
    scope RasterView!ushort source,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        require(
            convertExactRasterPlane!(ushort, float)(
                source,
                0,
                destination,
                0
            ) == ExactRasterConversionError.none,
            "ushort semantic engine failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeAllocatedPublic(
    scope RasterView!ushort source,
    size_t iterations,
    out size_t successes
)
@safe
{
    successes = 0;
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        auto result =
            source.tryConvertAllocated!float(0);

        require(
            result.ok,
            "allocated public conversion failed"
        );

        ++successes;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeAllocatedExplicit(
    scope RasterView!ushort source,
    size_t iterations,
    out size_t successes
)
@safe
{
    successes = 0;
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        auto allocated =
            allocateCompactRaster!float(
                source.width,
                source.height
            );

        require(
            allocated.error == CompactAllocationError.none,
            "explicit compact allocation failed"
        );

        bool writableOk;

        scope auto destination =
            allocated.lease.tryWritableView(
                writableOk
            );

        require(
            writableOk,
            "explicit writable destination unavailable"
        );

        RasterConversionError error;

        require(
            source.convertRasterInto!float(
                0,
                destination,
                0,
                error
            ),
            "explicit allocated conversion failed"
        );

        require(
            error == RasterConversionError.none,
            "explicit allocated conversion returned error"
        );

        ++successes;
    }

    return (MonoTime.currTime - start).total!"nsecs";
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


private void printPath(
    string pair,
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
        "conversion_benchmark compiler=%s pair=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(),
        pair,
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


private void printAllocatedPath(
    string path,
    size_t width,
    size_t height,
    size_t iterations,
    long medianNs,
    size_t successes
)
{
    const logicalSamples =
        cast(double)(width * height * iterations);

    writefln(
        "conversion_allocated compiler=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f successes=%s",
        compilerName(),
        path,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / logicalSamples,
        successes
    );
}


void main(string[] args)
@system
{
    const width =
        args.length >= 2 ? args[1].to!size_t : 2048;

    const height =
        args.length >= 3 ? args[2].to!size_t : 512;

    const iterations =
        args.length >= 4 ? args[3].to!size_t : 16;

    const allocatedIterations =
        args.length >= 5 ? args[4].to!size_t : 4;

    enum size_t rowPadding = 32;

    RasterLease!ubyte ubyteSourceLease;
    ubyte* ubyteSourceBase;
    size_t ubyteSourceRow;

    require(
        makeSourceLease!ubyte(
            width,
            height,
            rowPadding,
            31,
            ubyteSourceLease,
            ubyteSourceBase,
            ubyteSourceRow
        ),
        "ubyte source construction failed"
    );

    RasterLease!ushort ushortSourceLease;
    ushort* ushortSourceBase;
    size_t ushortSourceRow;

    require(
        makeSourceLease!ushort(
            width,
            height,
            rowPadding,
            47,
            ushortSourceLease,
            ushortSourceBase,
            ushortSourceRow
        ),
        "ushort source construction failed"
    );

    enum size_t destinationCount = 5;

    RasterLease!float[destinationCount] destinationLeases;
    float*[destinationCount] destinationBases;
    size_t[destinationCount] destinationRows;
    WritableRasterView!float[destinationCount] destinations;

    foreach (i; 0 .. destinationCount)
    {
        require(
            makeFloatLease(
                width,
                height,
                rowPadding,
                destinationLeases[i],
                destinationBases[i],
                destinationRows[i]
            ),
            "destination construction failed"
        );

        bool ok;

        destinations[i] =
            destinationLeases[i].tryWritableView(ok);

        require(
            ok,
            "writable destination unavailable"
        );
    }

    scope auto ubyteSource =
        ubyteSourceLease.view();

    scope auto ushortSource =
        ushortSourceLease.view();

    // Qualification pass.
    timeUbyteGeneric(
        ubyteSource,
        destinations[0],
        1
    );

    timeUbyteSpecialized(
        ubyteSource,
        destinations[1],
        1
    );

    timeUbyteSemantic(
        ubyteSource,
        destinations[2],
        1
    );

    timeUshortGeneric(
        ushortSource,
        destinations[3],
        1
    );

    timeUshortSemantic(
        ushortSource,
        destinations[4],
        1
    );

    ulong[destinationCount] firstChecksums;

    foreach (i; 0 .. destinationCount)
    {
        firstChecksums[i] =
            checksumFloat(
                destinationBases[i],
                width,
                height,
                destinationRows[i]
            );

        require(
            floatPaddingIsIntact(
                destinationBases[i],
                width,
                height,
                destinationRows[i]
            ),
            "destination padding modified during qualification"
        );
    }

    require(
        firstChecksums[0] == firstChecksums[1]
        && firstChecksums[1] == firstChecksums[2],
        "ubyte conversion checksum mismatch"
    );

    require(
        firstChecksums[3] == firstChecksums[4],
        "ushort conversion checksum mismatch"
    );

    auto allocatedCheck =
        ushortSource.tryConvertAllocated!float(0);

    require(
        allocatedCheck.ok,
        "allocated semantic preflight failed"
    );

    size_t ignoredSuccesses;

    timeAllocatedExplicit(
        ushortSource,
        1,
        ignoredSuccesses
    );

    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 3)
        {
            case 0:
                timeUbyteGeneric(ubyteSource, destinations[0], 1);
                timeUbyteSpecialized(ubyteSource, destinations[1], 1);
                timeUbyteSemantic(ubyteSource, destinations[2], 1);
                timeUshortGeneric(ushortSource, destinations[3], 1);
                timeUshortSemantic(ushortSource, destinations[4], 1);
                timeAllocatedPublic(ushortSource, 1, ignoredSuccesses);
                timeAllocatedExplicit(ushortSource, 1, ignoredSuccesses);
                break;

            case 1:
                timeUbyteSemantic(ubyteSource, destinations[2], 1);
                timeUbyteGeneric(ubyteSource, destinations[0], 1);
                timeUbyteSpecialized(ubyteSource, destinations[1], 1);
                timeUshortSemantic(ushortSource, destinations[4], 1);
                timeUshortGeneric(ushortSource, destinations[3], 1);
                timeAllocatedExplicit(ushortSource, 1, ignoredSuccesses);
                timeAllocatedPublic(ushortSource, 1, ignoredSuccesses);
                break;

            case 2:
                timeUbyteSpecialized(ubyteSource, destinations[1], 1);
                timeUbyteSemantic(ubyteSource, destinations[2], 1);
                timeUbyteGeneric(ubyteSource, destinations[0], 1);
                timeUshortGeneric(ushortSource, destinations[3], 1);
                timeUshortSemantic(ushortSource, destinations[4], 1);
                timeAllocatedPublic(ushortSource, 1, ignoredSuccesses);
                timeAllocatedExplicit(ushortSource, 1, ignoredSuccesses);
                break;
        }
    }

    long[samples] ubyteGenericTimes;
    long[samples] ubyteSpecializedTimes;
    long[samples] ubyteSemanticTimes;
    long[samples] ushortGenericTimes;
    long[samples] ushortSemanticTimes;
    long[samples] allocatedPublicTimes;
    long[samples] allocatedExplicitTimes;

    size_t allocatedPublicSuccesses;
    size_t allocatedExplicitSuccesses;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 3)
        {
            case 0:
                ubyteGenericTimes[sample] =
                    timeUbyteGeneric(
                        ubyteSource,
                        destinations[0],
                        iterations
                    );

                ubyteSpecializedTimes[sample] =
                    timeUbyteSpecialized(
                        ubyteSource,
                        destinations[1],
                        iterations
                    );

                ubyteSemanticTimes[sample] =
                    timeUbyteSemantic(
                        ubyteSource,
                        destinations[2],
                        iterations
                    );

                ushortGenericTimes[sample] =
                    timeUshortGeneric(
                        ushortSource,
                        destinations[3],
                        iterations
                    );

                ushortSemanticTimes[sample] =
                    timeUshortSemantic(
                        ushortSource,
                        destinations[4],
                        iterations
                    );

                allocatedPublicTimes[sample] =
                    timeAllocatedPublic(
                        ushortSource,
                        allocatedIterations,
                        allocatedPublicSuccesses
                    );

                allocatedExplicitTimes[sample] =
                    timeAllocatedExplicit(
                        ushortSource,
                        allocatedIterations,
                        allocatedExplicitSuccesses
                    );
                break;

            case 1:
                ubyteSemanticTimes[sample] =
                    timeUbyteSemantic(
                        ubyteSource,
                        destinations[2],
                        iterations
                    );

                ubyteGenericTimes[sample] =
                    timeUbyteGeneric(
                        ubyteSource,
                        destinations[0],
                        iterations
                    );

                ubyteSpecializedTimes[sample] =
                    timeUbyteSpecialized(
                        ubyteSource,
                        destinations[1],
                        iterations
                    );

                ushortSemanticTimes[sample] =
                    timeUshortSemantic(
                        ushortSource,
                        destinations[4],
                        iterations
                    );

                ushortGenericTimes[sample] =
                    timeUshortGeneric(
                        ushortSource,
                        destinations[3],
                        iterations
                    );

                allocatedExplicitTimes[sample] =
                    timeAllocatedExplicit(
                        ushortSource,
                        allocatedIterations,
                        allocatedExplicitSuccesses
                    );

                allocatedPublicTimes[sample] =
                    timeAllocatedPublic(
                        ushortSource,
                        allocatedIterations,
                        allocatedPublicSuccesses
                    );
                break;

            case 2:
                ubyteSpecializedTimes[sample] =
                    timeUbyteSpecialized(
                        ubyteSource,
                        destinations[1],
                        iterations
                    );

                ubyteSemanticTimes[sample] =
                    timeUbyteSemantic(
                        ubyteSource,
                        destinations[2],
                        iterations
                    );

                ubyteGenericTimes[sample] =
                    timeUbyteGeneric(
                        ubyteSource,
                        destinations[0],
                        iterations
                    );

                ushortGenericTimes[sample] =
                    timeUshortGeneric(
                        ushortSource,
                        destinations[3],
                        iterations
                    );

                ushortSemanticTimes[sample] =
                    timeUshortSemantic(
                        ushortSource,
                        destinations[4],
                        iterations
                    );

                allocatedPublicTimes[sample] =
                    timeAllocatedPublic(
                        ushortSource,
                        allocatedIterations,
                        allocatedPublicSuccesses
                    );

                allocatedExplicitTimes[sample] =
                    timeAllocatedExplicit(
                        ushortSource,
                        allocatedIterations,
                        allocatedExplicitSuccesses
                    );
                break;
        }
    }

    ulong[destinationCount] finalChecksums;

    foreach (i; 0 .. destinationCount)
    {
        finalChecksums[i] =
            checksumFloat(
                destinationBases[i],
                width,
                height,
                destinationRows[i]
            );

        require(
            floatPaddingIsIntact(
                destinationBases[i],
                width,
                height,
                destinationRows[i]
            ),
            "destination padding modified during timed work"
        );
    }

    require(
        finalChecksums[0] == finalChecksums[1]
        && finalChecksums[1] == finalChecksums[2],
        "timed ubyte conversion checksum mismatch"
    );

    require(
        finalChecksums[3] == finalChecksums[4],
        "timed ushort conversion checksum mismatch"
    );

    const ubyteGenericMedian =
        median(ubyteGenericTimes);

    const ubyteSpecializedMedian =
        median(ubyteSpecializedTimes);

    const ubyteSemanticMedian =
        median(ubyteSemanticTimes);

    const ushortGenericMedian =
        median(ushortGenericTimes);

    const ushortSemanticMedian =
        median(ushortSemanticTimes);

    const allocatedPublicMedian =
        median(allocatedPublicTimes);

    const allocatedExplicitMedian =
        median(allocatedExplicitTimes);

    printPath(
        "ubyte_to_float",
        "public_generic",
        width,
        height,
        iterations,
        ubyteGenericMedian,
        finalChecksums[0]
    );

    printPath(
        "ubyte_to_float",
        "public_specialized",
        width,
        height,
        iterations,
        ubyteSpecializedMedian,
        finalChecksums[1]
    );

    printPath(
        "ubyte_to_float",
        "semantic_engine",
        width,
        height,
        iterations,
        ubyteSemanticMedian,
        finalChecksums[2]
    );

    printPath(
        "ushort_to_float",
        "public_generic",
        width,
        height,
        iterations,
        ushortGenericMedian,
        finalChecksums[3]
    );

    printPath(
        "ushort_to_float",
        "semantic_engine",
        width,
        height,
        iterations,
        ushortSemanticMedian,
        finalChecksums[4]
    );

    printAllocatedPath(
        "public_allocated",
        width,
        height,
        allocatedIterations,
        allocatedPublicMedian,
        allocatedPublicSuccesses
    );

    printAllocatedPath(
        "explicit_allocate_convert",
        width,
        height,
        allocatedIterations,
        allocatedExplicitMedian,
        allocatedExplicitSuccesses
    );

    writefln(
        "conversion_ratio compiler=%s pair=ubyte_to_float generic_over_specialized=%.6f generic_over_semantic=%.6f specialized_over_semantic=%.6f",
        compilerName(),
        cast(double) ubyteGenericMedian
            / cast(double) ubyteSpecializedMedian,
        cast(double) ubyteGenericMedian
            / cast(double) ubyteSemanticMedian,
        cast(double) ubyteSpecializedMedian
            / cast(double) ubyteSemanticMedian
    );

    writefln(
        "conversion_ratio compiler=%s pair=ushort_to_float generic_over_semantic=%.6f",
        compilerName(),
        cast(double) ushortGenericMedian
            / cast(double) ushortSemanticMedian
    );

    writefln(
        "conversion_ratio compiler=%s pair=allocated_ushort_to_float public_over_explicit=%.6f",
        compilerName(),
        cast(double) allocatedPublicMedian
            / cast(double) allocatedExplicitMedian
    );
}
