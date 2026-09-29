module neighbourhood_parallel_bench;

import core.sync.barrier : Barrier;
import core.thread : Thread;
import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

import raster.internal.r0_5_neighbourhood_view_bench :
    CanonicalNeighbourhoodFixture,
    box3CanonicalRowRange,
    makeCanonicalNeighbourhoodFixture;

private enum size_t width = 2048;
private enum size_t height = 512;
private enum size_t pitch = 4096;
private enum size_t repetitions = 11;
private enum size_t warmups = 3;
private enum size_t[6] workerCounts = [1, 2, 3, 4, 6, 12];

private enum WorkerCommand : ubyte
{
    execute,
    shutdown
}

private __gshared ulong sink;

private uint bits(float value)
@trusted
pure
nothrow
@nogc
{
    union U { float f; uint u; }
    U u;
    u.f = value;
    return u.u;
}

private float logicalValue(size_t y, size_t x)
@safe
pure
nothrow
@nogc
{
    const i = y * (width + 2) + x;
    return cast(float)((i * 37 + (i >> 4) * 13) % 4093) * 0.00025f;
}

private void fillLogical(float[] storage, bool negativeRows)
@safe
nothrow
@nogc
{
    foreach (y; 0 .. height + 2)
        foreach (x; 0 .. width + 2)
        {
            const physicalY = negativeRows ? height + 1 - y : y;
            storage[physicalY * pitch + x] = logicalValue(y, x);
        }
}

private void oracle(float[] dst)
@safe
nothrow
@nogc
{
    foreach (y; 0 .. height)
        foreach (x; 0 .. width)
            dst[y * width + x] =
                logicalValue(y, x) + logicalValue(y, x + 1) + logicalValue(y, x + 2) +
                logicalValue(y + 1, x) + logicalValue(y + 1, x + 1) + logicalValue(y + 1, x + 2) +
                logicalValue(y + 2, x) + logicalValue(y + 2, x + 1) + logicalValue(y + 2, x + 2);
}

private void consume(scope const(float)[] dst)
@trusted
nothrow
@nogc
{
    ulong value = sink ^ 0x9e3779b97f4a7c15UL;
    foreach (y; 0 .. height)
    {
        const row = y * width;
        value = (value ^ bits(dst[row])) * 0x9e3779b185ebca87UL;
        value = (value ^ bits(dst[row + width - 1])) * 0xc2b2ae3d27d4eb4fUL;
    }
    sink = value;
}

private long median(scope long[] values)
{
    sort(values);
    return values[values.length / 2];
}

private final class RowWorker
{
    CanonicalNeighbourhoodFixture* fixture;
    Barrier startGate;
    Barrier completionGate;

    size_t rowBegin;
    size_t rowEnd;
    bool noInline;
    WorkerCommand command;
    bool executionOk = true;

    this(
        CanonicalNeighbourhoodFixture* fixture,
        Barrier startGate,
        Barrier completionGate
    )
    {
        this.fixture = fixture;
        this.startGate = startGate;
        this.completionGate = completionGate;
    }

    void run()
    {
        for (;;)
        {
            startGate.wait();

            if (command == WorkerCommand.shutdown)
            {
                completionGate.wait();
                return;
            }

            executionOk = box3CanonicalRowRange(
                fixture.source,
                fixture.target,
                rowBegin,
                rowEnd,
                noInline
            );

            completionGate.wait();
        }
    }
}

private final class PersistentRowTeam
{
    CanonicalNeighbourhoodFixture* fixture;
    RowWorker[] workers;
    Thread[] threads;
    Barrier startGate;
    Barrier completionGate;

    this(CanonicalNeighbourhoodFixture* fixture, size_t workerCount)
    {
        assert(workerCount != 0);
        assert(workerCount <= height);

        this.fixture = fixture;
        assert(workerCount < uint.max);
        const barrierParticipants = cast(uint)(workerCount + 1);
        startGate = new Barrier(barrierParticipants);
        completionGate = new Barrier(barrierParticipants);

        workers = new RowWorker[workerCount];
        threads = new Thread[workerCount];

        foreach (i; 0 .. workerCount)
        {
            workers[i] = new RowWorker(
                fixture,
                startGate,
                completionGate
            );
            threads[i] = new Thread(&workers[i].run);
            threads[i].start();
        }
    }

    bool execute(bool noInline)
    {
        const workerCount = workers.length;

        foreach (i, worker; workers)
        {
            worker.rowBegin = i * height / workerCount;
            worker.rowEnd = (i + 1) * height / workerCount;
            worker.noInline = noInline;
            worker.command = WorkerCommand.execute;
            worker.executionOk = true;
        }

        startGate.wait();
        completionGate.wait();

        foreach (worker; workers)
            if (!worker.executionOk)
                return false;

        return true;
    }

    void shutdown()
    {
        foreach (worker; workers)
            worker.command = WorkerCommand.shutdown;

        startGate.wait();
        completionGate.wait();

        foreach (thread; threads)
            thread.join();
    }
}

private int runCase(bool negativeRows, bool noInline)
{
    auto source = new float[pitch * (height + 2)];
    auto expected = new float[width * height];
    auto dst = new float[width * height];

    fillLogical(source, negativeRows);
    oracle(expected);

    auto fixture = makeCanonicalNeighbourhoodFixture(
        source,
        dst,
        width,
        height,
        pitch,
        negativeRows
    );

    bool runSerial()
    @safe
    nothrow
    @nogc
    {
        return box3CanonicalRowRange(
            fixture.source,
            fixture.target,
            0,
            height,
            noInline
        );
    }

    if (!runSerial() || dst != expected)
    {
        writefln(
            "neighbourhood3x3_parallel correctness_failed rows=%s kernel=%s phase=serial",
            negativeRows ? "negative" : "positive",
            noInline ? "noinline" : "inline"
        );
        return 1;
    }

    foreach (_; 0 .. warmups)
    {
        if (!runSerial())
            return 1;
        consume(dst);
    }

    long[repetitions] serialSamples;
    foreach (i; 0 .. repetitions)
    {
        const started = MonoTime.currTime;
        const ok = runSerial();
        serialSamples[i] = (MonoTime.currTime - started).total!"nsecs";
        if (!ok)
            return 1;
        consume(dst);
    }

    auto serialOrdered = serialSamples;
    const serialMedian = median(serialOrdered[]);

    writefln(
        "neighbourhood3x3_parallel rows=%s kernel=%s mode=serial workers=0 median_ns=%s raw_ns=%(%s,%) sink=%s",
        negativeRows ? "negative" : "positive",
        noInline ? "noinline" : "inline",
        serialMedian,
        serialSamples,
        sink
    );

    foreach (workerCount; workerCounts)
    {
        auto team = new PersistentRowTeam(&fixture, workerCount);

        if (!team.execute(noInline) || dst != expected)
        {
            writefln(
                "neighbourhood3x3_parallel correctness_failed rows=%s kernel=%s workers=%s",
                negativeRows ? "negative" : "positive",
                noInline ? "noinline" : "inline",
                workerCount
            );
            team.shutdown();
            return 1;
        }

        foreach (_; 0 .. warmups)
        {
            if (!team.execute(noInline))
            {
                team.shutdown();
                return 1;
            }
            consume(dst);
        }

        long[repetitions] samples;
        bool executionOk = true;

        foreach (i; 0 .. repetitions)
        {
            const started = MonoTime.currTime;
            const ok = team.execute(noInline);
            samples[i] = (MonoTime.currTime - started).total!"nsecs";
            executionOk = executionOk && ok;
            consume(dst);
        }

        team.shutdown();

        if (!executionOk || dst != expected)
            return 1;

        auto ordered = samples;
        const workerMedian = median(ordered[]);
        const speedup = cast(double) serialMedian / cast(double) workerMedian;
        const efficiency = speedup / cast(double) workerCount;

        writefln(
            "neighbourhood3x3_parallel rows=%s kernel=%s mode=persistent workers=%s median_ns=%s speedup_vs_serial=%.6f efficiency=%.6f raw_ns=%(%s,%) sink=%s",
            negativeRows ? "negative" : "positive",
            noInline ? "noinline" : "inline",
            workerCount,
            workerMedian,
            speedup,
            efficiency,
            samples,
            sink
        );
    }

    return 0;
}

int runNeighbourhoodParallelMatrix()
{
    writefln(
        "neighbourhood3x3_parallel topology=known_x86_64_6c12t_1numa width=%s height=%s pitch=%s workers=1,2,3,4,6,12 warmups=%s repetitions=%s",
        width,
        height,
        pitch,
        warmups,
        repetitions
    );

    foreach (negativeRows; [false, true])
        foreach (noInline; [false, true])
            if (runCase(negativeRows, noInline) != 0)
                return 1;

    return 0;
}
