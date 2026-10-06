# v0.2 generic sum qualification benchmark

Purpose: qualify Issue #101's generic strict `sum!Accumulator` family against:

- the frozen v0.1 `trySumFloatToDouble` implementation;
- a representative strict scalar C++ reference.

The representative workload is:

- Sample = `float`;
- Accumulator = `double`;
- 2048 x 512 logical samples by default;
- 32 padded float elements per physical row;
- strict logical row-major accumulation;
- no allocation inside the timed reduction;
- identical generated sample values.

The D binary times both:

~~~text
legacy  trySumFloatToDouble
generic source.sum!double
~~~

and requires exact `double` result-bit equality.

The C++ reference executes the same strict scalar row-major graph over the same
generated padded-row values. It includes a plane-index validity branch but is
not a complete RasterView/backing-validation implementation. Treat it as a
representative kernel-level C++ performance reference, not as proof of identical
library abstraction overhead.

## C++ compiler semantics

The runner uses:

~~~text
-O3
-std=c++20
-fno-fast-math
-ffp-contract=off
-fno-tree-vectorize
-fno-tree-slp-vectorize
~~~

for the strict scalar reference.

The intent is to prevent reassociation/tree reduction from changing the
numerical contract merely to make the C++ reference faster.

## Run on the reference XPS

From the repository root on branch `feat/v0.2-m3-generic-sum`:

~~~bash
bash benchmark/v0_2_sum/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_sum/run_xps.sh CPU OUTPUT_DIR
~~~

Defaults:

~~~text
CPU=0
OUTPUT_DIR=/tmp/raster-v0.2-sum-<timestamp>
~~~

The runner:

- records CPU/toolchain/environment information;
- builds fixed release binaries for DMD and LDC;
- builds one strict g++ reference binary;
- pins six independent processes per implementation to one CPU;
- records D legacy/generic and C++ ns/logical-sample;
- requires exact result-bit equality across D legacy, D generic and C++;
- verifies D timed checksums;
- reports medians/ranges;
- records compiler/frequency/thermal snapshots;
- writes SHA256SUMS;
- creates a tar.gz evidence archive.

Hosted GitHub CI only compile-smokes this benchmark. Hosted CI timing is not
accepted as performance qualification.
