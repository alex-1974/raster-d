module imagery.raster.alias_bench;

import core.stdc.stdlib :
    free,
    malloc;

import core.sys.posix.time :
    CLOCK_MONOTONIC,
    clock_gettime,
    timespec;

import ldc.attributes :
    restrict;

import mir.ndslice :
    Contiguous,
    Slice;

import imagery.raster.internal.scalar_conversion :
    scalarConvertUbyteToFloatContiguous1D;


/*
 * Prevent the benchmark driver itself from removing observable results.
 */
__gshared float benchmarkSink;


/*
 * Production-kernel adapter.
 *
 * The wrapper is deliberately not inlined so each measured iteration contains
 * one stable call boundary.
 */
pragma(inline, false)
extern(C)
bool mirConvert(
    const(ubyte)* source,
    float* target,
    size_t elementCount
)
@system
nothrow
@nogc
{
    auto sourceSlice =
        Slice!(
            const(ubyte)*,
            1,
            Contiguous
        )(
            [elementCount],
            source
        );

    auto targetSlice =
        Slice!(
            float*,
            1,
            Contiguous
        )(
            [elementCount],
            target
        );

    return
        scalarConvertUbyteToFloatContiguous1D(
            sourceSlice,
            targetSlice
        );
}


/*
 * Controlled baseline: no source/target alias promise.
 */
pragma(inline, false)
extern(C)
bool rawConvertUnknown(
    const(ubyte)* source,
    float* target,
    size_t elementCount
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. elementCount)
    {
        target[i] =
            cast(float)
                source[i];
    }

    return true;
}


/*
 * Experimental no-alias variant.
 *
 * Separate allocations used by this benchmark satisfy this precondition.
 */
pragma(inline, false)
extern(C)
bool rawConvertRestrict(
    @restrict const(ubyte)* source,
    @restrict float* target,
    size_t elementCount
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. elementCount)
    {
        target[i] =
            cast(float)
                source[i];
    }

    return true;
}


alias ConvertFn =
    extern(C)
    bool function(
        const(ubyte)*,
        float*,
        size_t
    )
    @system
    nothrow
    @nogc;


ulong monotonicNanoseconds()
@system
nothrow
@nogc
{
    timespec ts;

    const rc =
        clock_gettime(
            CLOCK_MONOTONIC,
            &ts
        );

    if (rc != 0)
        return 0;

    return
        cast(ulong) ts.tv_sec
            * 1_000_000_000UL
        + cast(ulong) ts.tv_nsec;
}


bool verify(
    const(ubyte)* source,
    const(float)* target,
    size_t elementCount
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. elementCount)
    {
        if (
            target[i]
            != cast(float) source[i]
        )
        {
            return false;
        }
    }

    return true;
}


ulong repetitionsFor(
    size_t elementCount
)
@safe
pure
nothrow
@nogc
{
    /*
     * Keep approximately constant converted-element work for medium/large
     * sizes while retaining enough calls to expose fixed overhead.
     */
    enum ulong targetElements =
        128UL * 1024UL * 1024UL;

    enum ulong maxRepetitions =
        2_000_000UL;

    enum ulong minRepetitions =
        16UL;

    ulong reps =
        targetElements
        / cast(ulong) elementCount;

    if (reps < minRepetitions)
        reps = minRepetitions;

    if (reps > maxRepetitions)
        reps = maxRepetitions;

    return reps;
}


ulong measure(
    ConvertFn operation,
    const(ubyte)* source,
    float* target,
    size_t elementCount,
    ulong repetitions
)
@system
nothrow
@nogc
{
    /*
     * Warm-up is outside the measured interval.
     */
    foreach (_; 0 .. 64)
    {
        if (
            !operation(
                source,
                target,
                elementCount
            )
        )
        {
            return ulong.max;
        }
    }

    const start =
        monotonicNanoseconds();

    foreach (_; 0 .. repetitions)
    {
        if (
            !operation(
                source,
                target,
                elementCount
            )
        )
        {
            return ulong.max;
        }
    }

    const stop =
        monotonicNanoseconds();

    /*
     * Observable read after the measured calls.
     */
    benchmarkSink =
        target[
            elementCount - 1
        ];

    return stop - start;
}


void runOne(
    const(char)[] name,
    ConvertFn operation,
    const(ubyte)* source,
    float* target,
    size_t elementCount,
    ulong repetitions,
    uint round
)
@system
{
    const elapsed =
        measure(
            operation,
            source,
            target,
            elementCount,
            repetitions
        );

    if (elapsed == ulong.max)
    {
        throw new Exception(
            "operation failure"
        );
    }

    if (
        !verify(
            source,
            target,
            elementCount
        )
    )
    {
        throw new Exception(
            "verification failure"
        );
    }

    const nsPerCall =
        cast(double) elapsed
        / cast(double) repetitions;

    const nsPerSample =
        nsPerCall
        / cast(double) elementCount;

    import std.stdio :
        writefln;

    writefln(
        "%s\t%d\t%d\t%d\t%d\t%.6f\t%.9f\t%.1f",
        name,
        elementCount,
        round,
        repetitions,
        elapsed,
        nsPerCall,
        nsPerSample,
        cast(double) benchmarkSink
    );
}


void main()
@system
{
    import std.stdio :
        writeln;

    const size_t[] sizes =
    [
        1,
        4,
        8,
        16,
        31,
        32,
        33,
        64,
        128,
        256,
        1_024,
        4_096,
        65_536,
        1_048_576,
        4_194_304
    ];

    enum uint rounds = 9;

    writeln(
        "variant\tn\tround\trepetitions\telapsed_ns\t"
        ~ "ns_per_call\tns_per_sample\tsink"
    );

    foreach (elementCount; sizes)
    {
        auto source =
            cast(ubyte*) malloc(
                elementCount
                * ubyte.sizeof
            );

        auto target =
            cast(float*) malloc(
                elementCount
                * float.sizeof
            );

        if (
            source is null
            || target is null
        )
        {
            throw new Exception(
                "allocation failure"
            );
        }

        scope(exit)
        {
            free(source);
            free(target);
        }

        foreach (i; 0 .. elementCount)
        {
            source[i] =
                cast(ubyte)(
                    (
                        i * 73
                        + 19
                    )
                    & 255
                );

            target[i] =
                -1.0f;
        }

        /*
         * Verify all three implementations before timing.
         */
        if (
            !mirConvert(
                source,
                target,
                elementCount
            )
            || !verify(
                source,
                target,
                elementCount
            )
        )
        {
            throw new Exception(
                "Mir correctness failure"
            );
        }

        if (
            !rawConvertUnknown(
                source,
                target,
                elementCount
            )
            || !verify(
                source,
                target,
                elementCount
            )
        )
        {
            throw new Exception(
                "raw unknown correctness failure"
            );
        }

        if (
            !rawConvertRestrict(
                source,
                target,
                elementCount
            )
            || !verify(
                source,
                target,
                elementCount
            )
        )
        {
            throw new Exception(
                "raw restrict correctness failure"
            );
        }

        const repetitions =
            repetitionsFor(
                elementCount
            );

        /*
         * Rotate execution order each round to reduce systematic
         * first/last-position bias.
         */
        foreach (round; 0 .. rounds)
        {
            final switch (round % 3)
            {
                case 0:
                    runOne(
                        "mir",
                        &mirConvert,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    runOne(
                        "raw_unknown",
                        &rawConvertUnknown,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    runOne(
                        "raw_restrict",
                        &rawConvertRestrict,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    break;

                case 1:
                    runOne(
                        "raw_unknown",
                        &rawConvertUnknown,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    runOne(
                        "raw_restrict",
                        &rawConvertRestrict,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    runOne(
                        "mir",
                        &mirConvert,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    break;

                case 2:
                    runOne(
                        "raw_restrict",
                        &rawConvertRestrict,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    runOne(
                        "mir",
                        &mirConvert,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    runOne(
                        "raw_unknown",
                        &rawConvertUnknown,
                        source,
                        target,
                        elementCount,
                        repetitions,
                        round
                    );

                    break;
            }
        }
    }
}
