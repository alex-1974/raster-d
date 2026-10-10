# raster-d 0.2.0 feature-freeze release benchmark

This package records the public Production benchmark baseline for the v0.2.0
feature-freeze source tree.

The frozen production source commit is:

```text
658f4fd48a2141b4434996e2ed9e1044bf0d5ad3
```

The immutable checkpoint is:

```text
freeze/feature-0.2.0
```

The benchmark imports only the public root module:

```d
import raster;
```

It uses no `raster.internal.*` symbol, research selector, or package-local
execution helper.

The workloads cover every qualified v0.2 performance family:

- same-type `ubyte` copy;
- exact `ubyte -> float` conversion on positive and negative-row sources;
- `ubyte` fill;
- unary float transform;
- binary float multiply with mixed row direction;
- strict `float -> double` reduction on a negative-row Canonical source;
- float 3x3 neighbourhood on a negative-row Canonical source;
- fixed float 3x3 convolution on padded positive rows.

Each workload constructs and validates retained backing before timing, warms up,
then records eleven timed samples. Checksums are computed outside the timed
region.

The collector builds one release binary for DMD and one for LDC, reuses each
exact binary for six independent CPU-pinned processes, records toolchain,
host, frequency and thermal provenance, and creates a recursive SHA256 manifest
plus tar archive.

The runner permits benchmark-harness changes after the freeze commit but
requires `source/raster` to remain byte-for-byte unchanged from the feature
freeze. This keeps the initial baseline tied to the frozen production source.

This is a stable Production baseline, not an A/B research benchmark. Absolute
times are reference-machine evidence only and are not CI thresholds.
