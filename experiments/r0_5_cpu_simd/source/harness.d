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
    {
        const started = MonoTime.currTime;
        operation();
        samples[i] = elapsedNanoseconds(started);
    }

    return SampleSet(samples);
}
