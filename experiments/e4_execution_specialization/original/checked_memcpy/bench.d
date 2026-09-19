module imagery.raster.e43b_bench;

import core.stdc.stdlib :
    free,
    malloc;

import core.stdc.string :
    memcpy;

import core.time :
    MonoTime;

import std.algorithm :
    min;

import std.stdio :
    writefln;

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.internal.copy_dispatch :
    tryCopyNonOverlappingContiguous1D;

import imagery.raster.internal.mir_adapter :
    asMirContiguousFlat;

import imagery.raster.internal.mir_target_adapter :
    asMirTargetContiguousFlat;

import imagery.raster.internal.scalar_pointwise :
    scalarCopyContiguous1D;

import imagery.raster.internal.target :
    RasterTargetPlane,
    tryBorrowContiguousTarget;

import imagery.raster.region :
    Region2D;

import imagery.raster.view :
    RasterView,
    makeRasterViewAssumeValidated;


private
ulong sink;


/*
 * Candidate E4.3b operation.
 *
 * It repeats exactly the control-plane checks needed by the production
 * dispatcher, then calls memcpy only after proving non-overlap.
 *
 * This is temporary benchmark code, not production code.
 */
private
bool checkedMemcpy(
    scope RasterView!ubyte source,
    size_t planeIndex,
    scope RasterTargetPlane!ubyte target
)
@trusted
nothrow
@nogc
{
    import imagery.raster.internal.execution_layout :
        PlaneExecutionTraits;

    PlaneExecutionTraits traits;

    if (
        !source.tryPlaneExecutionTraits(
            planeIndex,
            traits
        )
    )
    {
        return false;
    }

    if (
        source.width != target.width
        || source.height != target.height
    )
    {
        return false;
    }

    if (source.empty)
        return true;

    if (!traits.linearContiguous1D)
        return false;

    if (
        traits.flatElementCount
        != target.elementCount
    )
    {
        return false;
    }

    const sourceBase =
        source.executionRegionBase(
            planeIndex
        );

    auto targetBase =
        target.executionBase();

    if (
        sourceBase is null
        || targetBase is null
    )
    {
        return false;
    }

    const elementCount =
        traits.flatElementCount;

    if (
        elementCount
        > size_t.max / ubyte.sizeof
    )
    {
        return false;
    }

    const byteLength =
        elementCount * ubyte.sizeof;

    const sourceStart =
        cast(size_t) sourceBase;

    const targetStart =
        cast(size_t) targetBase;

    if (
        byteLength > size_t.max - sourceStart
        || byteLength > size_t.max - targetStart
    )
    {
        return false;
    }

    const sourceEnd =
        sourceStart + byteLength;

    const targetEnd =
        targetStart + byteLength;

    const nonOverlapping =
           sourceEnd <= targetStart
        || targetEnd <= sourceStart;

    if (!nonOverlapping)
        return false;

    memcpy(
        targetBase,
        sourceBase,
        byteLength
    );

    return true;
}


private
pragma(inline, false)
bool currentMirCopy(
    scope RasterView!ubyte source,
    scope RasterTargetPlane!ubyte target
)
@safe
nothrow
@nogc
{
    return scalarCopyContiguous1D(
        asMirContiguousFlat(
            source,
            0
        ),
        asMirTargetContiguousFlat(
            target
        )
    );
}


private
pragma(inline, false)
bool currentCheckedCopy(
    scope RasterView!ubyte source,
    scope RasterTargetPlane!ubyte target
)
@safe
nothrow
@nogc
{
    return tryCopyNonOverlappingContiguous1D(
        source,
        0,
        target
    ).ok;
}


private
pragma(inline, false)
bool directMemcpy(
    const(ubyte)* source,
    ubyte* target,
    size_t length
)
@trusted
nothrow
@nogc
{
    memcpy(
        target,
        source,
        length
    );

    return true;
}


private
pragma(inline, false)
bool candidateCheckedMemcpy(
    scope RasterView!ubyte source,
    scope RasterTargetPlane!ubyte target
)
@safe
nothrow
@nogc
{
    return checkedMemcpy(
        source,
        0,
        target
    );
}


private
ulong elapsedNs(
    void delegate() operation,
    size_t iterations
)
{
    const start =
        MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        operation();
    }

    const stop =
        MonoTime.currTime;

    return cast(ulong)(
        (stop - start).total!"nsecs"
    );
}


private
size_t iterationCount(
    size_t byteLength
)
{
    /*
     * Roughly 512 MiB transferred per timed sample, capped so tiny buffers
     * do not turn the benchmark into an excessively long function-call test.
     */
    enum size_t targetBytes =
        512UL * 1024 * 1024;

    enum size_t maxIterations =
        4_000_000;

    if (byteLength == 0)
        return 1;

    auto result =
        targetBytes / byteLength;

    if (result == 0)
        result = 1;

    return min(
        result,
        maxIterations
    );
}


private
void initialize(
    ubyte* source,
    ubyte* target,
    size_t length
)
@trusted
nothrow
@nogc
{
    foreach (i; 0 .. length)
    {
        source[i] =
            cast(ubyte)(
                i * 131 + 17
            );

        target[i] = 0;
    }
}


private
ubyte consume(
    ubyte* target,
    size_t length
)
@trusted
nothrow
@nogc
{
    if (length == 0)
        return 0;

    return target[
        (length * 17 + 3) % length
    ];
}


private
void benchmarkSize(
    size_t length
)
{
    const allocationLength =
        length == 0
        ? 1
        : length;

    auto sourceMemory =
        cast(ubyte*) malloc(
            allocationLength
        );

    auto targetMemory =
        cast(ubyte*) malloc(
            allocationLength
        );

    assert(sourceMemory !is null);
    assert(targetMemory !is null);

    initialize(
        sourceMemory,
        targetMemory,
        allocationLength
    );

    scope(exit)
    {
        free(sourceMemory);
        free(targetMemory);
    }

    PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceMemory,
            cast(ptrdiff_t) length,
            1
        )
    ];

    auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                length,
                1
            )
        );

    bool targetOk;

    auto target =
        tryBorrowContiguousTarget(
            targetMemory[
                0 .. length
            ],
            length,
            1,
            targetOk
        );

    assert(targetOk);

    const iterations =
        iterationCount(length);

    /*
     * Accumulate operation results into an observable value.
     *
     * The benchmark is compiled with -release, so using assert(operation())
     * would remove the complete operation call.
     */
    bool lastOk = true;

    /*
     * Warm each path.
     */
    foreach (_; 0 .. 32)
    {
        lastOk =
            currentMirCopy(
                source,
                target
            )
            ;

        lastOk =
            directMemcpy(
                sourceMemory,
                targetMemory,
                length
            )
            ;

        lastOk =
            currentCheckedCopy(
                source,
                target
            )
            ;

        lastOk =
            candidateCheckedMemcpy(
                source,
                target
            )
            ;
    }

    enum rounds = 7;

    ulong[rounds] mirTimes;
    ulong[rounds] memcpyTimes;
    ulong[rounds] checkedScalarTimes;
    ulong[rounds] checkedMemcpyTimes;

    foreach (round; 0 .. rounds)
    {
        /*
         * Rotate order to reduce systematic cache/frequency bias.
         */
        final switch (round % 4)
        {
            case 0:
                mirTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentMirCopy(source, target)
                                    ;
                        },
                        1
                    );

                memcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    directMemcpy(
                                        sourceMemory,
                                        targetMemory,
                                        length
                                    )
                                    ;
                        },
                        1
                    );

                checkedScalarTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentCheckedCopy(source, target)
                                    ;
                        },
                        1
                    );

                checkedMemcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    candidateCheckedMemcpy(source, target)
                                    ;
                        },
                        1
                    );

                break;

            case 1:
                memcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    directMemcpy(
                                        sourceMemory,
                                        targetMemory,
                                        length
                                    )
                                    ;
                        },
                        1
                    );

                checkedMemcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    candidateCheckedMemcpy(source, target)
                                    ;
                        },
                        1
                    );

                mirTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentMirCopy(source, target)
                                    ;
                        },
                        1
                    );

                checkedScalarTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentCheckedCopy(source, target)
                                    ;
                        },
                        1
                    );

                break;

            case 2:
                checkedScalarTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentCheckedCopy(source, target)
                                    ;
                        },
                        1
                    );

                mirTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentMirCopy(source, target)
                                    ;
                        },
                        1
                    );

                checkedMemcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    candidateCheckedMemcpy(source, target)
                                    ;
                        },
                        1
                    );

                memcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    directMemcpy(
                                        sourceMemory,
                                        targetMemory,
                                        length
                                    )
                                    ;
                        },
                        1
                    );

                break;

            case 3:
                checkedMemcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    candidateCheckedMemcpy(source, target)
                                    ;
                        },
                        1
                    );

                checkedScalarTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentCheckedCopy(source, target)
                                    ;
                        },
                        1
                    );

                memcpyTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    directMemcpy(
                                        sourceMemory,
                                        targetMemory,
                                        length
                                    )
                                    ;
                        },
                        1
                    );

                mirTimes[round] =
                    elapsedNs(
                        {
                            foreach (_; 0 .. iterations)
                                lastOk =
                                    currentMirCopy(source, target)
                                    ;
                        },
                        1
                    );

                break;
        }
    }

    auto sortedMir =
        mirTimes;

    auto sortedMemcpy =
        memcpyTimes;

    auto sortedCheckedScalar =
        checkedScalarTimes;

    auto sortedCheckedMemcpy =
        checkedMemcpyTimes;

    import std.algorithm :
        sort;

    sort(sortedMir[]);
    sort(sortedMemcpy[]);
    sort(sortedCheckedScalar[]);
    sort(sortedCheckedMemcpy[]);

    const mirMedian =
        sortedMir[rounds / 2];

    const memcpyMedian =
        sortedMemcpy[rounds / 2];

    const checkedScalarMedian =
        sortedCheckedScalar[rounds / 2];

    const checkedMemcpyMedian =
        sortedCheckedMemcpy[rounds / 2];

    /*
     * Make both operation success and copied target data observable outside
     * the timed regions.
     */
    sink +=
        lastOk
        ? 1UL
        : 0UL;

    sink +=
        consume(
            targetMemory,
            allocationLength
        );

    writefln(
        "%8s bytes  it=%-8s  "
        ~ "mir=%10s ns  memcpy=%10s ns  "
        ~ "checked-scalar=%10s ns  checked-memcpy=%10s ns  "
        ~ "mir/memcpy=%6.3f  checked-scalar/checked-memcpy=%6.3f",
        length,
        iterations,
        mirMedian,
        memcpyMedian,
        checkedScalarMedian,
        checkedMemcpyMedian,
        memcpyMedian == 0
            ? 0.0
            : cast(double) mirMedian / memcpyMedian,
        checkedMemcpyMedian == 0
            ? 0.0
            : cast(double) checkedScalarMedian / checkedMemcpyMedian
    );
}


void main()
{
    const sizes =
    [
        1UL,
        4,
        16,
        32,
        64,
        128,
        256,
        512,
        1_024,
        4_096,
        16_384,
        65_536,
        262_144,
        1_048_576,
        4_194_304,
        16_777_216
    ];

    foreach (size; sizes)
    {
        benchmarkSize(size);
    }

    writefln(
        "sink=%s",
        sink
    );
}
