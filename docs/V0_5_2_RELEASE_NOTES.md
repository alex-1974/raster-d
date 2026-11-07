# raster-d v0.5.2 release notes

`raster-d` v0.5.2 extends the opt-in data-plane execution API with scoped,
synchronous multi-phase row execution. It remains a generic raster facility:
image semantics, histogram policy and persistent scheduling remain outside the
package.

## Public API

- `ParallelRowsOperation`;
- `withPlanesParallel` for source-only row execution;
- `withPlanesParallelPhases`;
- `withPlanesIntoParallelPhases`.

Each phase is a full barrier. A caller can reduce private worker state and
derive parameters between phases while the validated raster windows remain
inside one synchronous borrow. Worker indices are stable within the operation.
Threads are created per phase and joined before the phase returns; no global or
persistent worker pool is introduced.

## Qualification

- DMD and LDC unit tests pass;
- source-only, source-to-destination, multi-phase, barrier, aliasing and
  callback-failure paths are covered;
- release benchmarks cover 1024×768 and 1920×1080, including the complete
  two-phase workload.
