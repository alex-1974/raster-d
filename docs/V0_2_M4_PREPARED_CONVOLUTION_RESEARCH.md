# raster-d v0.2 M4.6 — prepared convolution qualification research

Status: measurement harness for Issue #113.

Baseline:

~~~text
develop
f81d8ae5695da8dd71e98b823620c8d71e689d1e
~~~

## 1. Question

Issue #113 asks whether preparing invariant convolution state materially improves
repeated workloads enough to justify a production prepared-state API.

The answer must be evidence-driven.

No public prepared-state type is introduced by this research branch.

## 2. Existing one-shot baseline

M4.5 already provides compile-time fixed convolution:

~~~text
FixedConvolutionKernel
convolveInto
~~~

For that family:

- shape is compile-time;
- coefficient values are compile-time;
- accumulator type is compile-time;
- the kernel stores no runtime fields;
- centered 3x3 still reaches the qualified neighbourhood specialization.

This is already a highly prepared representation from the compiler's point of
view.

Therefore any additional runtime prepared state carries a high burden of proof.

## 3. Research candidate

The benchmark defines a private research-only prepared candidate:

~~~text
PreparedKernel3x3
    double[9] coefficients
~~~

Preparation converts nine runtime float coefficients to double once.

The repeated candidate path then receives:

- prepared double coefficients;
- already validated Canonical source pointer;
- already validated destination pointer;
- row strides;
- width/height.

It runs a direct fixed 3x3 pointer loop.

## 4. Deliberate bias in favor of prepared state

The prepared candidate intentionally receives an advantage over the production
one-shot API.

Its repeated timing excludes:

- source/destination plane validation;
- output-region validation;
- halo validation;
- injectivity validation;
- overlap classification;
- public API dispatch;
- coefficient conversion.

The production one-shot timing includes ordinary convolveInto structural
preflight.

This makes the benchmark conservative against the one-shot API.

Interpretation:

### If prepared does not materially win

A production prepared-state type is not justified for fixed kernels.

### If prepared materially wins

The result only justifies further research.

It does not by itself prove that coefficient preparation caused the win, because
the research candidate also bypasses structural validation.

A follow-up apples-to-apples executor design would then be required before
public API promotion.

## 5. Numerical equivalence

Both paths use:

~~~text
float source/output
float coefficients
double accumulator
3x3 fixed row-major term order
one final double -> float cast
~~~

Both paths must produce identical output checksums before timing results are
accepted.

## 6. Representative workload

Default workload:

~~~text
output width  = 1024
output height = 512
source halo   = 1 sample on every side
source row padding = 32 floats
iterations per timed sample = 8
timed samples per process = 16
independent pinned processes = 6
~~~

This exercises a large repeated spatial workload rather than a tiny kernel-call
microbenchmark.

## 7. Required measurements

The harness records exactly the Issue #113 requirements.

### Repeated one-shot latency

~~~text
mode=one_shot
ns_per_pixel
~~~

### Preparation cost

Nine runtime float coefficients are converted into the prepared double array.

~~~text
mode=prepare
ns_per_prepare
~~~

Preparation is repeated many times inside one timing batch to make this very
small cost measurable.

### Prepared repeated latency

~~~text
mode=prepared
ns_per_pixel
~~~

### Approximate break-even reuse count

For each process:

~~~text
per_call_savings =
    one_shot_call_time - prepared_call_time

break_even_reuse =
    preparation_time / per_call_savings
~~~

If prepared is not faster, break-even is infinite.

Because the candidate is deliberately advantaged, a finite break-even is only a
research signal, not automatic production acceptance.

## 8. DMD and LDC

The reference runner builds and records both:

~~~text
DMD
LDC
~~~

separately.

Prepared-state policy must not be inferred from only one compiler if the other
behaves materially differently.

## 9. Frequency and thermal control

The XPS runner:

- pins each process to one CPU;
- runs six independent processes per compiler;
- alternates one-shot/prepared timing order inside samples;
- records CPU frequency/governor snapshots;
- records thermal-zone snapshots;
- writes SHA256SUMS;
- creates a tar.gz evidence archive.

## 10. Hosted CI

Fast CI compile-smokes the benchmark with DMD and LDC.

Hosted CI timing is not accepted as #113 performance qualification because its
hardware and scheduling are not a stable benchmark environment.

## 11. Reference-XPS command

From repository root:

~~~bash
git switch research/v0.2-m4-prepared-convolution
git pull --ff-only origin research/v0.2-m4-prepared-convolution

bash benchmark/v0_2_prepared_convolution/run_xps.sh
~~~

The resulting archive and console summary are the evidence required to make the
M4.6 production decision.

## 12. Production decision gate

Prepared state may enter production only if all of the following are true:

1. repeated prepared latency materially beats one-shot on consumer-scale work;
2. the result is reproducible across pinned process runs;
3. DMD and LDC behavior is understood;
4. break-even reuse count is realistic for consumers;
5. a less-biased follow-up confirms the gain is not mainly validation bypass;
6. the one-shot fixed-kernel API remains coherent and first-class;
7. prepared state does not introduce hidden scheduling or unrelated image
   semantics.

Otherwise the production decision is:

~~~text
do not promote prepared convolution state
~~~

and the compile-time fixed one-shot family remains the v0.2 contract.

## 13. Current status

The measurement harness is implemented.

No production prepared-state type has been promoted.

Issue #113 remains open until reference-XPS evidence is recorded and the
decision gate is evaluated.
