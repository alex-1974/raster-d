# Unified Result API migration

This branch migrates fallible public raster operations to `error-d.Result`.
The migration is intentionally boundary-only: inner traversal, validation,
dispatch and allocation kernels keep their specialized status/result carriers.

## Public rule

Fallible public operations return one of:

```d
Result!(Value, LibraryError)
Result!(void, LibraryError)
```

Existing library-specific error enums remain the error domains. They are not
replaced by one global raster error enum.

## Ownership rule

Owning success payloads use `takeValue()` at transfer points. Ownership failure
details are represented by an explicit failure payload rather than by a second
parallel status channel. Pre-commit and post-commit resource disposition must
remain observable.

## Migration order

1. Numeric value reductions and histograms.
2. Allocating transform and conversion.
3. Layout conversion and construction results.
4. Single-resource and owned-resource import results.
5. Public validation results where they cross a library boundary.
6. External probes, documentation, benchmarks and consumer libraries.

## Performance gate

No `Result` value is introduced inside a per-sample or per-pixel loop. Before
publication, DMD and LDC benchmarks must compare the migrated boundary against
the current baseline for serial, ROI, strided and parallel workloads.

## Current status

Completed on this branch:

- `histogram256`
- `histogramInto`
- `sum`, `mean`, `min`, `max`, `minMax`
- `tryTransformAllocated`
- `tryConvertAllocated`

The remaining ownership/import chain is migrated as one dependency-ordered
unit so that resource disposition cannot be lost between layers.
