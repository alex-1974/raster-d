# raster-d v0.5 — bounded parallel row kernels

## Scope

`withPlanesIntoParallel` is an opt-in execution primitive for independent
logical rows. It is part of raster-d's generic data-plane API and does not
encode an imagery operation, sample-type pair, queue policy, or application
scheduler.

`withPlanesParallel` is the source-only sibling for analysis passes that do
not produce a raster. `ParallelRowsOperation` provides the common scoped
multi-phase barrier primitive: callers may execute multiple row phases and
perform their reduction between calls to `forRows`. Worker indices are stable
within the operation. Threads are still created per phase and joined before
the phase returns; persistent worker reuse remains outside raster-d.

When inputs are stored in separate backings, `withViewsParallelPhases` and
`withViewsIntoParallelPhases` expose the same contract over an array of
read-only source views. Every view is validated independently before the
callback is entered, and all views must have the same logical extent. The
source array is homogeneous by sample type; this keeps the callback strongly
typed and allocation-free while still covering RGB plus a separately backed
byte mask. A different sample domain can be coordinated by the caller around
the same phase state.

## Execution contract

- `workerLimit == 0` means the sequential path.
- `workerLimit == 1` always uses the sequential path.
- `minimumChunk` controls the smallest logical batch used for partitioning.
- Workers are created for one invocation only.
- Every started worker is joined before the function returns.
- No process-global pool or persistent scheduler is installed.
- A successful return means every assigned callback returned `true`.
- A failed return may leave partial destination writes.

The callback is `@safe nothrow`. It receives callback-scoped windows and a
half-open row range `[firstRow, endRow)`. It must write only that range, must
not retain any argument, and must not start work that outlives the enclosing
call.

## Memory and aliasing

The same affine stride and alias validation applies as for `withPlanesInto`:

- source/source overlap is allowed;
- destination/destination overlap is rejected unless disjointness is proven;
- source/destination overlap is rejected unless disjointness is proven;
- signed row and sample strides remain supported;
- ROI offsets remain part of the validated view geometry.

The implementation does not weaken alias validation to accommodate a
particular interleaved consumer. A consumer requiring a specialized affine
proof must provide that proof as a separately reviewed raster-domain
extension.

## Scheduling boundary

`concurrency-d` is a suitable owner for persistent workers, bounded queues,
worker reuse, cancellation, and application-wide scheduling. raster-d only
owns the synchronous row-kernel boundary needed to keep its validated borrows
alive. An executor dependency must not be introduced merely to accelerate this
API.

## Qualification

The release benchmark covers 1024×768 and 1920×1080, DMD and LDC, multiple
worker limits, and multiple chunk sizes. Correctness is checked with DMD and
LDC unit tests, and the worker path is race-tested with LDC ThreadSanitizer
where supported.
