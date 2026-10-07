# v0.2 allocated transform qualification benchmark

Purpose: close the remaining M5.1 unary-transform coverage gap without changing
the already-qualified destination-oriented transform harness.

The benchmark compares the allocating convenience wrapper against the equivalent
explicit production sequence:

~~~text
public_allocated
    tryTransformAllocated!pointTransform

explicit_allocate_transform
    allocateCompactRaster!float
    -> writable view
    -> transformInto!pointTransform
~~~

Both paths therefore include:

- compact allocation;
- retained backing construction;
- writable-view acquisition;
- the same public destination-oriented transform engine;
- destruction/release of the temporary output owner.

The benchmark does not expose the private Canonical executor and does not add a
second transform implementation. Existing M3.2b / ADR 0011 evidence remains the
executor-level qualification, while
`benchmark/v0_2_transform_into` remains the accepted destination-oriented API
bridge evidence.

Representative workload:

- float;
- 2048 x 512 logical samples;
- source rows padded by 32 elements;
- Canonical source sample stride 1;
- 6 warmups;
- 18 rotating timed samples;
- 4 allocations/transforms per timed sample;
- six independent CPU-pinned processes per compiler.

Before timed work, both paths are executed once and their output checksums must
match. Timed samples record successful materializations and rotate measurement
order.

Run from repository root on the reference XPS:

~~~bash
bash benchmark/v0_2_transform_allocated/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_transform_allocated/run_xps.sh CPU OUTPUT_DIR
~~~

The runner records repository head, baseline, compiler/tool versions,
CPU/platform, affinity, frequency/thermal snapshots, build logs, six process
outputs per compiler, summary statistics, SHA256SUMS and a tar.gz archive.

Hosted CI only compile-smokes this harness; hosted timing is not qualification
evidence.
