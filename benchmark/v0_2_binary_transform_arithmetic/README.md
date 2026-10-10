# v0.2 binary transform / arithmetic benchmark

Purpose: qualify the M5.1 binary-transform/arithmetic family against the actual
v0.2 public semantic paths and the already-approved Canonical zip executor.

Representative workload:

- sample type: `float`;
- default logical shape: 2048 x 512;
- 32 elements of row padding on both inputs and destinations;
- all sample strides equal one (Canonical);
- independent left/right/destination backing;
- no allocation in any timed operation;
- deterministic nonzero right operand for division;
- six independent pinned reference-XPS processes per compiler;
- DMD and LDC release builds.

Measured layers:

~~~text
add:
    public_zip
        left.zipTransformInto!addFloat(...)
    public_wrapper
        left.addInto(...)
    hot_executor
        executeApprovedCanonicalZipTransform!addFloat(...)

subtract / multiply / divide:
    public_wrapper
    hot_executor
~~~

The add triplet measures both wrapper overhead and the complete
public-semantic/preflight/dispatch cost relative to the approved Canonical
executor. The other arithmetic operations keep the same structural path and
measure whether the numeric kernel changes the public/executor relationship.

All compared paths for one operation must produce identical logical checksums.
Destination row padding is also verified unchanged after the timed work.

This harness deliberately uses the existing package-internal approved executor;
it does not introduce a second production loop and does not expose the executor
through the public API.

## Reference XPS

From repository root:

~~~bash
bash benchmark/v0_2_binary_transform_arithmetic/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_binary_transform_arithmetic/run_xps.sh CPU OUTPUT_DIR
~~~

Defaults:

~~~text
CPU=0
OUTPUT_DIR=/tmp/raster-v0.2-binary-transform-arithmetic-<timestamp>
~~~

The runner records repository head, branch, compiler/tool versions, CPU/OS,
affinity, frequency/thermal snapshots, build logs, six process outputs per
compiler, median/range summaries, SHA256SUMS and a tar.gz archive.

Hosted CI compile-smokes this harness under the required DMD/LDC matrix.
Absolute hosted-runner timing is not accepted as qualification evidence.

A C++ comparison is intentionally deferred to M5.7 / Issue #121 so this M5.1
family qualification does not mix semantic-layer isolation with a separate
cross-language gate.
