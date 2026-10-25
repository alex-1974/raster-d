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
import core.atomic : MemoryOrder, atomicLoad, atomicStore;

/// The result reported by a row callback.
enum ParallelRowsResult { completed, callbackFailed }

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

