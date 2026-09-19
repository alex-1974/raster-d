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


extern(C)
{
    double sumStrict(
        const(float)*,
        size_t
    )
    @system nothrow @nogc;

    double sumLane4(
        const(float)*,
        size_t
    )
    @system nothrow @nogc;

    double sumLane8(
        const(float)*,
        size_t
    )
    @system nothrow @nogc;

    double sumFast(
        const(float)*,
        size_t
    )
    @system nothrow @nogc;
}


enum Dataset
{
    positive,
    signed,
    cancel
}


struct Timing
{
    ulong ns;
    double sink;
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


uint rng(ref uint state)
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


void fill(
    float* data,
    size_t length,
    Dataset dataset
)
@system
nothrow
@nogc
{
    uint state =
        0x1234_5678;

    final switch (dataset)
    {
        case Dataset.positive:
        {
            foreach (i; 0 .. length)
            {
                const uint r =
                    rng(state);

                data[i] =
                    cast(float)
                    (
                        (r & 0x00ff_ffff)
                        / cast(double) 0x0100_0000
                    );
            }

            break;
        }

        case Dataset.signed:
        {
            foreach (i; 0 .. length)
            {
                const uint r =
                    rng(state);

                const double x =
                    (r & 0x00ff_ffff)
                    / cast(double) 0x0100_0000;

                data[i] =
                    cast(float)
                        (2.0 * x - 1.0);
            }

            break;
        }

        case Dataset.cancel:
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


double neumaier(
    const(float)* data,
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
            cast(double) data[i];

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


Timing timeStrict(
    const(float)* data,
    size_t length,
    size_t repetitions
)
@system
{
    double sink = 0.0;

    const ulong begin =
        nowNs();

    foreach (_; 0 .. repetitions)
        sink += sumStrict(data, length);

    return Timing(
        nowNs() - begin,
        sink
    );
}


Timing timeLane4(
    const(float)* data,
    size_t length,
    size_t repetitions
)
@system
{
    double sink = 0.0;

    const ulong begin =
        nowNs();

    foreach (_; 0 .. repetitions)
        sink += sumLane4(data, length);

    return Timing(
        nowNs() - begin,
        sink
    );
}


Timing timeLane8(
    const(float)* data,
    size_t length,
    size_t repetitions
)
@system
{
    double sink = 0.0;

    const ulong begin =
        nowNs();

    foreach (_; 0 .. repetitions)
        sink += sumLane8(data, length);

    return Timing(
        nowNs() - begin,
        sink
    );
}


Timing timeFast(
    const(float)* data,
    size_t length,
    size_t repetitions
)
@system
{
    double sink = 0.0;

    const ulong begin =
        nowNs();

    foreach (_; 0 .. repetitions)
        sink += sumFast(data, length);

    return Timing(
        nowNs() - begin,
        sink
    );
}


void emit(
    string name,
    string dataset,
    size_t length,
    size_t round,
    size_t repetitions,
    Timing timing
)
{
    const double samples =
        cast(double) length
        * repetitions;

    writefln(
        "timing,%s,%s,%d,%d,%d,%.9f,%.17g",
        name,
        dataset,
        length,
        round,
        repetitions,
        cast(double) timing.ns / samples,
        timing.sink
    );
}


void bench(
    size_t length,
    Dataset dataset,
    string datasetName
)
@system
{
    auto data =
        cast(float*) malloc(
            length * float.sizeof
        );

    assert(data !is null);

    fill(
        data,
        length,
        dataset
    );


    const double reference =
        neumaier(data, length);

    const double strict =
        sumStrict(data, length);

    const double lane4 =
        sumLane4(data, length);

    const double lane8 =
        sumLane8(data, length);

    const double fast =
        sumFast(data, length);


    writefln(
        "accuracy,%s,%d,"
        ~ "%.17g,%.17g,%.17g,%.17g,%.17g",
        datasetName,
        length,
        reference,
        strict,
        lane4,
        lane8,
        fast
    );


    const size_t bytes =
        length * float.sizeof;

    enum size_t targetBytes =
        128UL * 1024 * 1024;

    size_t repetitions =
        targetBytes / bytes;

    if (repetitions < 8)
        repetitions = 8;

    if (repetitions > 500_000)
        repetitions = 500_000;


    /*
     * Warm all implementations.
     */
    foreach (_; 0 .. 16)
    {
        sumStrict(data, length);
        sumLane4(data, length);
        sumLane8(data, length);
        sumFast(data, length);
    }


    foreach (round; 0 .. 7)
    {
        Timing strictTiming;
        Timing lane4Timing;
        Timing lane8Timing;
        Timing fastTiming;

        /*
         * Rotate execution order each round.
         */
        final switch (round & 3)
        {
            case 0:
                strictTiming =
                    timeStrict(data, length, repetitions);
                lane4Timing =
                    timeLane4(data, length, repetitions);
                lane8Timing =
                    timeLane8(data, length, repetitions);
                fastTiming =
                    timeFast(data, length, repetitions);
                break;

            case 1:
                lane4Timing =
                    timeLane4(data, length, repetitions);
                lane8Timing =
                    timeLane8(data, length, repetitions);
                fastTiming =
                    timeFast(data, length, repetitions);
                strictTiming =
                    timeStrict(data, length, repetitions);
                break;

            case 2:
                lane8Timing =
                    timeLane8(data, length, repetitions);
                fastTiming =
                    timeFast(data, length, repetitions);
                strictTiming =
                    timeStrict(data, length, repetitions);
                lane4Timing =
                    timeLane4(data, length, repetitions);
                break;

            case 3:
                fastTiming =
                    timeFast(data, length, repetitions);
                strictTiming =
                    timeStrict(data, length, repetitions);
                lane4Timing =
                    timeLane4(data, length, repetitions);
                lane8Timing =
                    timeLane8(data, length, repetitions);
                break;
        }

        emit(
            "strict",
            datasetName,
            length,
            round,
            repetitions,
            strictTiming
        );

        emit(
            "lane4",
            datasetName,
            length,
            round,
            repetitions,
            lane4Timing
        );

        emit(
            "lane8",
            datasetName,
            length,
            round,
            repetitions,
            lane8Timing
        );

        emit(
            "fast",
            datasetName,
            length,
            round,
            repetitions,
            fastTiming
        );
    }


    free(data);
}


void main()
@system
{
    foreach (length;
    [
        1024UL,
        65536UL,
        1UL * 1024 * 1024,
        16UL * 1024 * 1024
    ])
    {
        bench(
            length,
            Dataset.positive,
            "positive"
        );

        bench(
            length,
            Dataset.signed,
            "signed"
        );

        bench(
            length,
            Dataset.cancel,
            "cancel"
        );
    }
}
