# raster-d 0.1.0 release benchmark

This package is a release-qualification consumer for the frozen public
`raster` API. It intentionally imports only the root module:

```d
import raster;
```

No `raster.internal.*` symbol, research selector or package-local helper is
used.

The benchmark covers representative public M2/M3 operations on the reference
x86-64 platform:

- same-type ubyte Copy;
- exact ubyte-to-float conversion, including the negative-source layout used by
  the qualified LDC optimizer-boundary specialization;
- ubyte fill;
- float point transform;
- strict float-to-double reduction on a negative-row Canonical source;
- float 3x3 neighbourhood on a negative-row Canonical source.

Each workload constructs and validates retained backing before timing, warms up,
then records eleven median samples. Correctness/checksum validation occurs
outside the timed region.

The collector builds one release binary per compiler, reuses that exact binary
for six independent CPU-pinned processes, records toolchain/host/frequency and
thermal provenance, and creates a recursive SHA256 manifest plus tar archive.

This is a stable Production baseline, not an A/B research benchmark. Absolute
times are reference-machine evidence only and are not CI thresholds.
