/**
    Bounded, caller-configured row-range execution.

    This module deliberately contains no raster-specific scheduler or pool.
    Each invocation owns the threads it creates and joins them before it
    returns.  The callback receives only a logical row range; callers keep
    their validated RasterPlaneWindow borrows in the enclosing synchronous
    scope.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-25
*/
module raster.parallel_rows;

import core.thread : Thread;
import core.atomic : MemoryOrder, atomicFetchAdd, atomicLoad, atomicStore;

/// The result reported by a row callback.
enum ParallelRowsResult { completed, callbackFailed }

/**
    A caller-scoped row execution context.

    The context may be used for more than one phase.  Each `forRows` call is
    a full barrier: it does not return until every callback started for that
    phase has returned.  Worker indices are stable within the operation and
    are never used concurrently by two callbacks in one phase.

    Threads are owned by each phase and are joined before the phase returns;
    this deliberately does not introduce a persistent scheduler or pool.
*/
struct ParallelRowsOperation
{
private:
    size_t rowCount_;
    size_t workerLimit_;
    size_t minimumChunk_;

public:
    this(size_t rowCount, size_t workerLimit, size_t minimumChunk)
    @safe pure nothrow @nogc
    {
        rowCount_ = rowCount;
        workerLimit_ = workerLimit;
        minimumChunk_ = minimumChunk;
    }

    ParallelRowsResult forRows(
        scope bool delegate(size_t workerIndex, size_t firstRow,
            size_t endRow) @safe nothrow callback
    ) @trusted nothrow
    {
        if (callback is null || rowCount_ == 0)
            return callback is null ? ParallelRowsResult.callbackFailed
                : ParallelRowsResult.completed;

        const chunk = minimumChunk_ == 0 ? 1 : minimumChunk_;
        const workers = workerLimit_ == 0 ? 1 : workerLimit_;
        if (workers == 1 || rowCount_ <= chunk)
            return callback(0, 0, rowCount_)
                ? ParallelRowsResult.completed : ParallelRowsResult.callbackFailed;

        const chunkCount = rowCount_ / chunk + (rowCount_ % chunk != 0);
        const activeWorkers = workers < chunkCount ? workers : chunkCount;
        shared int failed;
        Thread[] threads;

        void run(size_t workerIndex)
        {
            const firstChunk = (chunkCount * workerIndex) / activeWorkers;
            const lastChunk = (chunkCount * (workerIndex + 1)) / activeWorkers;
            const first = firstChunk * chunk;
            const last = (lastChunk * chunk < rowCount_)
                ? lastChunk * chunk : rowCount_;
            if (first < last
                && atomicLoad!(MemoryOrder.acq)(failed) == 0
                && !callback(workerIndex, first, last))
                atomicStore!(MemoryOrder.rel)(failed, 1);
        }

        try
        {
            foreach (i; 0 .. activeWorkers)
            {
                const workerIndex = i;
                threads ~= new Thread({ run(workerIndex); });
            }
            foreach (thread; threads) thread.start();
            foreach (thread; threads)
                try thread.join();
                catch (Throwable) return ParallelRowsResult.callbackFailed;
        }
        catch (Throwable)
        {
            foreach (thread; threads)
                try
                {
                    if (thread.isRunning) thread.join();
                }
                catch (Throwable) { }
            return ParallelRowsResult.callbackFailed;
        }
        return atomicLoad!(MemoryOrder.acq)(failed) != 0
            ? ParallelRowsResult.callbackFailed : ParallelRowsResult.completed;
    }
}

/**
    Executes a bounded set of logical row ranges synchronously.

    `callback` receives a half-open range `[firstRow, endRow)`.  It must not
    retain the range or start work that outlives this call.  Returning false
    stops admission of new ranges; already-started callbacks are still joined
    before this function returns.  Partial writes are therefore possible and
    callers must publish output only after `completed`.

    No process-global worker pool is used.  `workerLimit == 1`, an empty
    range, and ranges below `minimumChunk` use the sequential path.
*/
ParallelRowsResult parallelRows(
    size_t rowCount,
    size_t workerLimit,
    size_t minimumChunk,
    scope bool delegate(size_t firstRow, size_t endRow) @safe nothrow callback
)
@trusted
{
    if (callback is null)
        return ParallelRowsResult.callbackFailed;
    if (rowCount == 0)
        return ParallelRowsResult.completed;

    const chunk = minimumChunk == 0 ? 1 : minimumChunk;
    const workers = workerLimit == 0 ? 1 : workerLimit;
    if (workers == 1 || rowCount <= chunk)
        return callback(0, rowCount)
            ? ParallelRowsResult.completed : ParallelRowsResult.callbackFailed;

    // Avoid `rowCount + chunk - 1`: both inputs are size_t and the public
    // contract must remain valid at the representational upper boundary.
    const chunkCount = rowCount / chunk + (rowCount % chunk != 0);
    const activeWorkers = workers < chunkCount ? workers : chunkCount;
    shared int failed;
    Thread[] threads;

    void run(size_t workerIndex)
    {
        const firstChunk = (chunkCount * workerIndex) / activeWorkers;
        const lastChunk = (chunkCount * (workerIndex + 1)) / activeWorkers;
        const first = firstChunk * chunk;
        const last = (lastChunk * chunk < rowCount)
            ? lastChunk * chunk : rowCount;
        if (first < last
            && atomicLoad!(MemoryOrder.acq)(failed) == 0
            && !callback(first, last))
        {
            atomicStore!(MemoryOrder.rel)(failed, 1);
        }
    }

    Thread makeThread(size_t workerIndex)
    {
        return new Thread({ run(workerIndex); });
    }

    try
    {
        foreach (i; 0 .. activeWorkers)
            threads ~= makeThread(i);
        foreach (thread; threads)
            thread.start();
        foreach (thread; threads)
            thread.join();
    }
    catch (Throwable)
    {
        foreach (thread; threads)
            if (thread.isRunning) thread.join();
        return ParallelRowsResult.callbackFailed;
    }

    return atomicLoad!(MemoryOrder.acq)(failed) != 0
        ? ParallelRowsResult.callbackFailed
        : ParallelRowsResult.completed;
}

@safe unittest
{
    size_t calls;
    assert(parallelRows(0, 4, 1, (size_t a, size_t b) nothrow { ++calls; return true; })
        == ParallelRowsResult.completed);
    assert(calls == 0);
    assert(parallelRows(3, 1, 1, (size_t a, size_t b) nothrow { ++calls; return true; })
        == ParallelRowsResult.completed);
    assert(calls == 1);
}

@safe unittest
{
    auto operation = ParallelRowsOperation(17, 1, 2);
    auto seen = new size_t[17];
    auto workers = new size_t[1];
    assert(operation.forRows(
        (size_t worker, size_t first, size_t last) nothrow
        {
            ++workers[worker];
            foreach (row; first .. last)
                atomicFetchAdd!(MemoryOrder.rel)(seen[row], 1);
            return true;
        }) == ParallelRowsResult.completed);
    foreach (count; seen) assert(count == 1);
    assert(operation.forRows(
        (size_t worker, size_t first, size_t last) nothrow
        {
            ++workers[worker];
            return true;
        }) == ParallelRowsResult.completed);
    foreach (count; workers) assert(count == 2);
}

@safe unittest
{
    auto operation = ParallelRowsOperation(8, 1, 1);
    bool secondPhaseRan;
    auto first = operation.forRows(
        (size_t worker, size_t firstRow, size_t endRow) nothrow
        {
            return false;
        });
    assert(first == ParallelRowsResult.callbackFailed);
    // The operation is synchronous; the caller decides whether a later phase
    // is meaningful after observing the failed result.
    if (first == ParallelRowsResult.completed)
        operation.forRows(
            (size_t worker, size_t firstRow, size_t endRow) nothrow
            {
                secondPhaseRan = true;
                return true;
            });
    assert(!secondPhaseRan);
}

@safe unittest
{
    auto seen = new size_t[17];
    assert(parallelRows(17, 4, 2,
        (size_t first, size_t last) nothrow
        {
            foreach (row; first .. last) ++seen[row];
            return true;
        }) == ParallelRowsResult.completed);
    foreach (count; seen) assert(count == 1);
}

@safe unittest
{
    size_t calls;
    assert(parallelRows(100, 4, 1,
        (size_t first, size_t last) nothrow
        {
            ++calls;
            return first == 0;
        }) == ParallelRowsResult.callbackFailed);
    assert(calls >= 1);
}

@safe unittest
{
    // The partition arithmetic must not wrap before the sequential fallback.
    size_t first;
    size_t last;
    assert(parallelRows(size_t.max, 1, size_t.max,
        (size_t a, size_t b) nothrow { first = a; last = b; return true; })
        == ParallelRowsResult.completed);
    assert(first == 0 && last == size_t.max);
}

