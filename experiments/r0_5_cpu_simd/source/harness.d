module harness;

import core.time : MonoTime;

struct SampleSet
{
    long[] nanoseconds;

    @property long median() const
    {
        assert(nanoseconds.length != 0);

        auto ordered = nanoseconds.dup;
        ordered.sortInPlace();

        return ordered[ordered.length / 2];
    }
}

struct PairSamples
{
    SampleSet first;
    SampleSet second;
}

private void sortInPlace(long[] values)
@safe
nothrow
@nogc
{
    foreach (i; 1 .. values.length)
    {
        const key = values[i];
        size_t j = i;

        while (j > 0 && values[j - 1] > key)
        {
            values[j] = values[j - 1];
            --j;
        }

        values[j] = key;
    }
}

long elapsedNanoseconds(MonoTime start)
@safe
nothrow
@nogc
{
    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeOnce(alias operation)()
{
    const started = MonoTime.currTime;
    operation();
    return elapsedNanoseconds(started);
}

SampleSet measure(alias operation)(
    size_t repetitions,
    size_t warmupRounds
)
{
    assert(repetitions != 0);

    foreach (_; 0 .. warmupRounds)
        operation();

    auto samples = new long[repetitions];

    foreach (i; 0 .. repetitions)
        samples[i] = timeOnce!operation();

    return SampleSet(samples);
}

PairSamples measurePair(alias first, alias second)(
    size_t repetitions,
    size_t warmupRounds
)
{
    assert(repetitions != 0);

    foreach (_; 0 .. warmupRounds)
    {
        first();
        second();
    }

    auto firstSamples = new long[repetitions];
    auto secondSamples = new long[repetitions];

    foreach (i; 0 .. repetitions)
    {
        if ((i & 1) == 0)
        {
            firstSamples[i] = timeOnce!first();
            secondSamples[i] = timeOnce!second();
        }
        else
        {
            secondSamples[i] = timeOnce!second();
            firstSamples[i] = timeOnce!first();
        }
    }

    return PairSamples(
        SampleSet(firstSamples),
        SampleSet(secondSamples)
    );
}
