# raster-d v0.5.1 release notes

`raster-d` v0.5.1 adds a generic, opt-in parallel row-kernel primitive to the
callback-scoped data-plane API. It is independent of imagery-d and does not
install a process-wide scheduler.

## Public API

- `parallelRows`
- `ParallelRowsResult`
- `withPlanesIntoParallel`

The callback receives callback-scoped source/destination windows and a
half-open logical row range. It must be `@safe nothrow`, write only its assigned
rows, and must not retain borrowed arguments. All workers are joined before
return. Failed callbacks may leave partial destination writes.

## Qualification

- DMD and LDC unit tests pass.
- LDC ThreadSanitizer unit tests pass.
- Tests cover negative row strides, ROI geometry, alias rejection, callback
  failure, sequential fallback and multi-worker coverage.
- The release benchmark covers 1024×768 and 1920×1080 with multiple worker
  limits and chunk sizes.

Persistent worker reuse, queueing, cancellation and affinity remain caller
responsibilities and are not part of raster-d's public scheduler contract.
