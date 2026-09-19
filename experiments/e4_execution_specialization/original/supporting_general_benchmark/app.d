module app;

import core.stdc.math :
    fabs;

import core.stdc.stdlib :
    free,
    malloc;

import core.sys.posix.time :
    CLOCK_MONOTONIC,
    clock_gettime,
    timespec;

import std.stdio :
    writefln;


/*
 * Deliberately declarations only.
 *
 * The benchmark translation unit cannot inspect the kernel bodies, so LLVM
 * cannot hoist or replace repeated reductions based on whole-unit analysis.
 */
extern(C)
{
    bool copyUnknownAlias(
        const(ubyte)* source,
        ubyte* target,
        size_t length
    )
    @system
    nothrow
    @nogc;


    bool copyNoAlias(
        const(ubyte)* source,
        ubyte* target,
        size_t length
    )
    @system
    nothrow
    @nogc;


    double sumStrict(
        const(float)* source,
        size_t length
    )
    @system
    nothrow
    @nogc;


    double sumFixedLane4(
        const(float)* source,
        size_t length
    )
    @system
    nothrow
    @nogc;


    double sumFast(
        const(float)* source,
        size_t length
    )
    @system
    nothrow
    @nogc;
}


/*
 * Compensated accuracy reference.
 *
 * Not timed.
 */
double sumNeumaier(
    const(float)* source,
    size_t length
)
@system
nothrow
@nogc
{
    double sum = 0.0;
    double correction = 0.0;

    foreach (i; 0 .. length)
    {
        const double value =
            cast(double) source[i];

        const double next =
            sum + value;

        if (fabs(sum) >= fabs(value))
        {
            correction +=
                (sum - next)
                + value;
        }
        else
        {
            correction +=
                (value - next)
                + sum;
        }

        sum = next;
    }

    return sum + correction;
}


ulong nowNs()
@system
nothrow
@nogc
{
    timespec ts;

    clock_gettime(
        CLOCK_MONOTONIC,
        &ts
    );

    return
        cast(ulong) ts.tv_sec
            * 1_000_000_000UL
        + cast(ulong) ts.tv_nsec;
}


uint nextRandom(ref uint state)
@safe
pure
nothrow
@nogc
{
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;

    return state;
}


void fillCopy(
    ubyte* source,
    ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. length)
    {
        source[i] =
            cast(ubyte)
                ((i * 131 + 17) & 0xff);

        target[i] = 0;
    }
}


enum FloatDataset
{
    imageryPositive,
    signedModerate,
    adversarialCancellation
}


void fillFloat(
    float* data,
    size_t length,
    FloatDataset dataset
)
@system
nothrow
@nogc
{
    uint state =
        0x1234_5678;

    final switch (dataset)
    {
        case FloatDataset.imageryPositive:
        {
            foreach (i; 0 .. length)
            {
                const uint r =
                    nextRandom(state);

                data[i] =
                    cast(float)
                    (
                        (r & 0x00ff_ffff)
                        / cast(double) 0x0100_0000
                    );
            }

            break;
        }

        case FloatDataset.signedModerate:
        {
            foreach (i; 0 .. length)
            {
                const uint r =
                    nextRandom(state);

                const double normalized =
                    (r & 0x00ff_ffff)
                    / cast(double) 0x0100_0000;

                data[i] =
                    cast(float)
                        (normalized * 2.0 - 1.0);
            }

            break;
        }

        case FloatDataset.adversarialCancellation:
        {
            foreach (i; 0 .. length)
            {
                final switch (i & 3)
                {
                    case 0:
                        data[i] = 1.0e20f;
                        break;

                    case 1:
                        data[i] = 1.0f;
                        break;

                    case 2:
                        data[i] = -1.0e20f;
                        break;

                    case 3:
                        data[i] = 1.0f;
                        break;
                }
            }

            break;
        }
    }
}


double relativeError(
    double candidate,
    double reference
)
@safe
pure
nothrow
@nogc
{
    const double absolute =
        fabs(candidate - reference);

    const double scale =
        fabs(reference);

    if (scale == 0.0)
        return absolute;

    return absolute / scale;
}


void benchmarkCopySize(
    size_t length
)
@system
{
    auto source =
        cast(ubyte*) malloc(length);

    auto target =
        cast(ubyte*) malloc(length);

    assert(source !is null);
    assert(target !is null);

    fillCopy(
        source,
        target,
        length
    );


    enum size_t targetBytes =
        256UL * 1024 * 1024;

    size_t repetitions =
        targetBytes / length;

    if (repetitions < 16)
        repetitions = 16;

    if (repetitions > 2_000_000)
        repetitions = 2_000_000;


    /*
     * Warm both implementations.
     */
    foreach (_; 0 .. 32)
    {
        copyUnknownAlias(
            source,
            target,
            length
        );

        copyNoAlias(
            source,
            target,
            length
        );
    }


    ulong start =
        nowNs();

    foreach (_; 0 .. repetitions)
    {
        copyUnknownAlias(
            source,
            target,
            length
        );
    }

    const ulong unknownNs =
        nowNs() - start;


    start =
        nowNs();

    foreach (_; 0 .. repetitions)
    {
        copyNoAlias(
            source,
            target,
            length
        );
    }

    const ulong noAliasNs =
        nowNs() - start;


    /*
     * Keep final writes externally observable to the benchmark process.
     */
    const ubyte guard =
        target[length - 1];


    const double totalBytes =
        cast(double) length
        * cast(double) repetitions;

    const double unknownGiBs =
        totalBytes
        / cast(double) unknownNs
        * 1.0e9
        / (1024.0 * 1024.0 * 1024.0);

    const double noAliasGiBs =
        totalBytes
        / cast(double) noAliasNs
        * 1.0e9
        / (1024.0 * 1024.0 * 1024.0);


    writefln(
        "copy,%d,%d,%d,%d,%.6f,%.6f,%.6f,%d",
        length,
        repetitions,
        unknownNs,
        noAliasNs,
        unknownGiBs,
        noAliasGiBs,
        unknownGiBs == 0.0
            ? 0.0
            : noAliasGiBs / unknownGiBs,
        guard
    );


    free(source);
    free(target);
}


void benchmarkSum(
    size_t length,
    FloatDataset dataset,
    string datasetName
)
@system
{
    const size_t bytes =
        length * float.sizeof;

    auto data =
        cast(float*) malloc(bytes);

    assert(data !is null);

    fillFloat(
        data,
        length,
        dataset
    );


    const double reference =
        sumNeumaier(
            data,
            length
        );

    const double strictResult =
        sumStrict(
            data,
            length
        );

    const double fixedResult =
        sumFixedLane4(
            data,
            length
        );

    const double fastResult =
        sumFast(
            data,
            length
        );


    enum size_t targetBytes =
        128UL * 1024 * 1024;

    size_t repetitions =
        targetBytes / bytes;

    if (repetitions < 8)
        repetitions = 8;

    if (repetitions > 500_000)
        repetitions = 500_000;


    /*
     * Warm all variants.
     */
    double sink = 0.0;

    foreach (_; 0 .. 16)
    {
        sink +=
            sumStrict(
                data,
                length
            );

        sink +=
            sumFixedLane4(
                data,
                length
            );

        sink +=
            sumFast(
                data,
                length
            );
    }


    ulong start =
        nowNs();

    foreach (_; 0 .. repetitions)
    {
        sink +=
            sumStrict(
                data,
                length
            );
    }

    const ulong strictNs =
        nowNs() - start;


    start =
        nowNs();

    foreach (_; 0 .. repetitions)
    {
        sink +=
            sumFixedLane4(
                data,
                length
            );
    }

    const ulong fixedNs =
        nowNs() - start;


    start =
        nowNs();

    foreach (_; 0 .. repetitions)
    {
        sink +=
            sumFast(
                data,
                length
            );
    }

    const ulong fastNs =
        nowNs() - start;


    const double samples =
        cast(double) length
        * cast(double) repetitions;


    const double strictNsPerSample =
        cast(double) strictNs
        / samples;

    const double fixedNsPerSample =
        cast(double) fixedNs
        / samples;

    const double fastNsPerSample =
        cast(double) fastNs
        / samples;


    writefln(
        "sum,%s,%d,%d,"
        ~ "%.8f,%.8f,%.8f,"
        ~ "%.6f,%.6f,"
        ~ "%.17g,%.17g,%.17g,%.17g,"
        ~ "%.6e,%.6e,%.6e,"
        ~ "%.6e",
        datasetName,
        length,
        repetitions,

        strictNsPerSample,
        fixedNsPerSample,
        fastNsPerSample,

        fixedNs == 0
            ? 0.0
            : cast(double) strictNs
                / cast(double) fixedNs,

        fastNs == 0
            ? 0.0
            : cast(double) strictNs
                / cast(double) fastNs,

        reference,
        strictResult,
        fixedResult,
        fastResult,

        relativeError(
            strictResult,
            reference
        ),

        relativeError(
            fixedResult,
            reference
        ),

        relativeError(
            fastResult,
            reference
        ),

        sink
    );


    free(data);
}


void main()
@system
{
    writefln(
        "# COPY"
    );

    writefln(
        "# kind,length,repetitions,"
        ~ "unknown_ns,noalias_ns,"
        ~ "unknown_GiBps,noalias_GiBps,"
        ~ "noalias_speedup,guard"
    );


    foreach (length;
    [
        64UL,
        256UL,
        1024UL,
        4096UL,
        65536UL,
        1UL * 1024 * 1024,
        16UL * 1024 * 1024
    ])
    {
        benchmarkCopySize(
            length
        );
    }


    writefln("");
    writefln(
        "# SUM"
    );

    writefln(
        "# kind,dataset,length,repetitions,"
        ~ "strict_ns_per_sample,"
        ~ "fixed4_ns_per_sample,"
        ~ "fast_ns_per_sample,"
        ~ "strict_over_fixed4,"
        ~ "strict_over_fast,"
        ~ "reference,strict,fixed4,fast,"
        ~ "strict_relerr,fixed4_relerr,fast_relerr,"
        ~ "sink"
    );


    foreach (length;
    [
        64UL,
        1024UL,
        65536UL,
        1UL * 1024 * 1024,
        16UL * 1024 * 1024
    ])
    {
        benchmarkSum(
            length,
            FloatDataset.imageryPositive,
            "positive"
        );

        benchmarkSum(
            length,
            FloatDataset.signedModerate,
            "signed"
        );

        benchmarkSum(
            length,
            FloatDataset.adversarialCancellation,
            "cancel"
        );
    }
}
