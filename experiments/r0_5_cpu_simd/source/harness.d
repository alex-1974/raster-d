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


struct FourSamples
{
    SampleSet first;
    SampleSet second;
    SampleSet third;
    SampleSet fourth;
}

FourSamples measureFour(alias first, alias second, alias third, alias fourth)(
    size_t repetitions,
    size_t warmupRounds
)
{
    assert(repetitions != 0);

    foreach (_; 0 .. warmupRounds)
    {
        first();
        second();
        third();
        fourth();
    }

    auto firstSamples = new long[repetitions];
    auto secondSamples = new long[repetitions];
    auto thirdSamples = new long[repetitions];
    auto fourthSamples = new long[repetitions];

    foreach (i; 0 .. repetitions)
    {
        final switch (i & 3)
        {
        case 0:
            firstSamples[i] = timeOnce!first();
            secondSamples[i] = timeOnce!second();
            thirdSamples[i] = timeOnce!third();
            fourthSamples[i] = timeOnce!fourth();
            break;
        case 1:
            secondSamples[i] = timeOnce!second();
            thirdSamples[i] = timeOnce!third();
            fourthSamples[i] = timeOnce!fourth();
            firstSamples[i] = timeOnce!first();
            break;
        case 2:
            thirdSamples[i] = timeOnce!third();
            fourthSamples[i] = timeOnce!fourth();
            firstSamples[i] = timeOnce!first();
            secondSamples[i] = timeOnce!second();
            break;
        case 3:
            fourthSamples[i] = timeOnce!fourth();
            firstSamples[i] = timeOnce!first();
            secondSamples[i] = timeOnce!second();
            thirdSamples[i] = timeOnce!third();
            break;
        }
    }

    return FourSamples(
        SampleSet(firstSamples),
        SampleSet(secondSamples),
        SampleSet(thirdSamples),
        SampleSet(fourthSamples)
    );
}
