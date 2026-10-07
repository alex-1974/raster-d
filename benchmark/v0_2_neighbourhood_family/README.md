# v0.2 neighbourhood family qualification benchmark

Purpose: close the final M5.1 neighbourhood/convolution coverage gap without
changing production visibility or reintroducing prepared convolution state.

The retained M4.6 convolution harness already separates:

~~~text
public convolveInto
approved direct-fixed execution control
rejected runtime prepared-state candidate
~~~

This harness adds the missing generic neighbourhood-family evidence.

It measures three production questions.

## 1. Centered 3 x 3 layering

~~~text
public_generic_3x3
    applyNeighbourhoodInto!(Shape3x3, weighted3x3)

public_legacy_3x3
    tryApplyRasterNeighbourhood3x3!weighted3x3

hot_executor_3x3
    executeApprovedNeighbourhood3x3!weighted3x3
~~~

The hot executor is the already-approved package execution entry. No private
production helper is exposed for benchmarking.

The generic 3 x 3 spelling must produce exactly the same logical output as the
legacy public operation and approved executor.

## 2. Generic 5 x 3 Canonical execution

~~~text
public_generic_5x3_canonical
    applyNeighbourhoodInto!(Shape5x3, weighted5x3)
~~~

This exercises the non-3x3 generic shape path with unit sample strides.

## 3. Generic 5 x 3 signed-affine fallback

~~~text
public_generic_5x3_strided
    applyNeighbourhoodInto!(Shape5x3, weighted5x3)
~~~

Source and destination use sample stride 2 while preserving the same logical
values. The output must be bit-identical to the Canonical 5 x 3 result.

This supplies a representative layout-specialization comparison without adding
a second algorithm.

## Representative workload

- sample type: float;
- output: 1024 x 512;
- source rows padded by 32 physical float elements;
- 3x3 halo: one sample each side;
- 5x3 halo: two samples horizontally, one vertically;
- strided case: sample stride 2;
- 6 warmups;
- 18 rotating timed samples per process;
- 8 iterations per timed sample;
- 6 independent CPU-pinned processes per compiler.

No allocation occurs inside timed neighbourhood operations. Source and
destination backing are created before timing and remain physically disjoint.

All compared semantic equivalents must produce identical output checksums.

## Interpretation

The benchmark separates:

- v0.2 generic public spelling from the preserved qualified 3x3 public path;
- public semantic/preflight cost from the approved 3x3 hot executor;
- generic non-3x3 Canonical execution from its signed-affine fallback.

It does not claim that a 3x3 hot-executor ratio is numerically transferable to
5x3. The 5x3 private Canonical helper remains private.

The existing M4.6 convolution evidence remains the convolution member of the
family and is not rerun here.

Run on the reference XPS:

~~~bash
bash benchmark/v0_2_neighbourhood_family/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_neighbourhood_family/run_xps.sh CPU OUTPUT_DIR
~~~

Hosted CI only compile-smokes this harness. Hosted timing is not reference
performance evidence.
