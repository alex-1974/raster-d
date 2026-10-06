# v0.2 transformInto qualification benchmark

Purpose: qualify the v0.2 transformInto API introduced for issue #95 against
the already-qualified v0.1 tryTransformRasterPlane implementation.

The benchmark intentionally compares two public call surfaces over the same
semantic operation and the same padded float workload:

- legacy: tryTransformRasterPlane!pointTransform
- v0.2: source.transformInto!pointTransform

Both paths must produce the same checksum.

This benchmark does not introduce a new algorithm or performance target. The
v0.2 API delegates to the existing point-transform engine. The qualification
question is whether the new public wrapper adds any material overhead after
release compilation.

Reference historical evidence

The v0.1.0 release baseline recorded the padded float point transform at:

- DMD 2.111: 1.040911 ns/pixel
- LDC 1.41: 0.202841 ns/pixel

Those values are reference-machine evidence only, not portable guarantees.

Run on the reference XPS

From the repository root on branch feat/v0.2-m2-transform-into:

    bash benchmark/v0_2_transform_into/run_xps.sh

Optional arguments:

    bash benchmark/v0_2_transform_into/run_xps.sh CPU OUTPUT_DIR

Defaults:

- CPU: 0
- output: /tmp/raster-v0.2-transform-into-<timestamp>

The runner:

- builds one fixed release binary per compiler;
- uses DMD and LDC;
- pins six independent processes per compiler to one CPU;
- records legacy and transformInto ns/pixel;
- verifies identical checksums;
- reports legacy/new ratios;
- creates a SHA256 manifest and tar archive.

Acceptance direction

This benchmark is intended to provide the representative performance baseline
required by #95. Timing should be interpreted as equivalence/no-material-wrapper
overhead evidence, not as a new speedup claim.

GitHub-hosted CI remains correctness/compile-contract evidence and is not used
as a stable performance gate.


## First diagnostic run — not qualification evidence

The first XPS archive:

    raster-v0.2-transform-into-20261006-125147.tar.gz
    SHA256 70fabc573fc49551b459437b39344be7695cc52ff7b33222951b1a669ffa161d

passed manifest verification and checksum equality, but is deliberately not
accepted as performance qualification.

That harness measured all legacy samples before all transformInto samples inside
each process. The result showed:

    DMD median legacy/new ratio 0.924718
    LDC median legacy/new ratio 1.128844

with LDC process ratios ranging from 0.810332 to 1.991492.

This spread and the systematic DMD second-half slowdown make thermal/frequency
and measurement-order bias materially confounded with API cost.

The revised harness therefore:

- uses one shared source and separate equivalent destinations;
- warms both public call surfaces;
- pairs legacy and transformInto inside every timed sample;
- alternates which API is measured first on every sample;
- records frequency/thermal snapshots before and after every process.

Only the revised run is eligible as #95 performance evidence.
