# v0.2 reduction family qualification benchmark

Purpose: close the remaining M5.1 reduction coverage for `min`, `max`,
`minMax` and `mean` while preserving the already-qualified
`benchmark/v0_2_sum` evidence.

The benchmark does not add alternate reduction algorithms.

For extrema, it compares the public result-carrier wrappers with the existing
package semantic engine:

~~~text
min:
    public_min
    semantic_min

max:
    public_max
    semantic_max

minMax:
    public_minmax
    semantic_minmax
~~~

It also records `public_min_plus_max`, the cost of two independent public
passes, as an informational control for the one-pass `minMax` contract.

For mean, the public operation is compared with the exact explicit composition
that defines its implementation contract:

~~~text
public_mean
    source.mean!(double, double)(0)

explicit_sum_divide
    source.sum!double(0)
    -> divide once by width * height
~~~

The representative workload is:

- Sample = `float`;
- mean Accumulator/Result = `double`;
- 2048 x 512 logical samples;
- 32 padded float elements per physical row;
- Canonical sample stride 1;
- deterministic finite values with no NaN/Inf;
- no allocation inside timed reductions;
- 6 warmups;
- 18 rotating timed samples;
- 16 iterations per timed sample;
- six independent CPU-pinned processes per compiler.

Semantic preflight requires exact bit equality between each public path and its
corresponding semantic/explicit control.

Run from repository root on the reference XPS:

~~~bash
bash benchmark/v0_2_reduction_family/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_reduction_family/run_xps.sh CPU OUTPUT_DIR
~~~

The runner records repository head, harness base, toolchain, CPU/platform,
affinity, frequency/thermal snapshots, compiler build logs, six process results
per compiler, summary statistics, SHA256SUMS and a tar.gz evidence archive.

Hosted CI only compile-smokes the harness. Hosted timing is not accepted as
reference performance evidence.
