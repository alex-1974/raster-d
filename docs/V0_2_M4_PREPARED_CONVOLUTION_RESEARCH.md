# raster-d v0.2 M4.6 — prepared convolution qualification research

Status: qualification complete; prepared runtime coefficient state rejected for production.

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

Issue #113 can close once this final reference-XPS evidence and decision are integrated.


## 14. Follow-up isolation benchmark

The first reference-XPS run showed a very large gap between the public one-shot
path and the deliberately advantaged prepared candidate:

~~~text
DMD:
    one-shot  100.903678 ns/pixel
    prepared   10.490990 ns/pixel
    ratio       9.644405x

LDC:
    one-shot   16.305238 ns/pixel
    prepared    2.421022 ns/pixel
    ratio       6.756027x
~~~

Those results are reproducible across six pinned processes and both paths
produced checksum:

~~~text
7596c236fe0ac383
~~~

However this does not isolate coefficient preparation because the prepared
candidate also bypasses structural validation and public API dispatch.

The original break-even calculation also divided preparation cost by the
savings of the complete multi-iteration timing batch rather than one convolution
invocation. That value is therefore not accepted as the final reuse threshold.

A second qualification run now adds:

~~~text
direct_fixed
~~~

This path uses the same validation-free Canonical execution shape as prepared
but keeps the convolution coefficients compile-time fixed.

The decisive comparisons become:

~~~text
one_shot / direct_fixed
    -> repeated validation / public dispatch effect

direct_fixed / prepared
    -> prepared runtime coefficient-state effect
~~~

Prepared-state production promotion must be based on the second comparison, not
on the original one-shot/prepared gap.

The corrected break-even calculation uses preparation cost divided by savings
per single convolution invocation.


## 15. Final reference-XPS isolation evidence

The second reference-XPS run used the isolation harness from:

~~~text
benchmark HEAD:
074c3f9cce2982176268b894e5dbf6e780c88d60

archive:
raster-v0.2-prepared-convolution-20261006-213617.tar.gz

archive SHA256:
e432900bdefc0e6b5b4eeca604667b0d06069ff236c3666c14cc02f787185e4b
~~~

No additional prepared-convolution benchmark run is required for M4.6.

All timed execution modes produced checksum:

~~~text
7596c236fe0ac383
~~~

### DMD 2.111.0

Six pinned process runs produced:

~~~text
one_shot_n=6
median_ns_per_pixel=107.191503
min=106.150500
max=108.647124

direct_fixed_n=6
median_ns_per_pixel=10.442197
min=10.354889
max=10.605424

prepared_n=6
median_ns_per_pixel=10.440517
min=10.388581
max=10.631346

prepare_n=6
median_ns_per_prepare=1.165500
min=1.165500
max=1.179500
~~~

The public-path overhead signal was:

~~~text
one_shot_over_direct_fixed_n=6
median=10.274735
min=10.107153
max=10.395756
~~~

The isolated prepared-state signal was:

~~~text
direct_fixed_over_prepared_n=6
median=1.000142
min=0.987192
max=1.003855
~~~

Three runs produced formally finite break-even values, but only because the
measured advantage was at noise level:

~~~text
prepared_break_even_reuse_finite_n=3
median=0.001068915
min=0.000825682
max=0.002961610
~~~

The median difference between direct-fixed and prepared is about 0.014 percent,
and the process ratios cross both sides of 1.0. DMD therefore shows no material,
reproducible benefit from runtime prepared coefficient state.

### LDC 1.41.0

Six pinned process runs produced:

~~~text
one_shot_n=6
median_ns_per_pixel=16.832161
min=16.732717
max=16.914678

direct_fixed_n=6
median_ns_per_pixel=1.621008
min=1.609015
max=1.642942

prepared_n=6
median_ns_per_pixel=2.382672
min=2.360487
max=2.395868

prepare_n=6
median_ns_per_prepare=1.165500
min=1.165500
max=1.179500
~~~

The public-path overhead signal was:

~~~text
one_shot_over_direct_fixed_n=6
median=10.374125
min=10.250595
max=10.416368
~~~

The isolated prepared-state signal was:

~~~text
direct_fixed_over_prepared_n=6
median=0.680331
min=0.672684
max=0.695998
~~~

No run produced a finite break-even:

~~~text
prepared_break_even_reuse_finite_n=0
~~~

At the medians, prepared execution is about 1.47 times the direct-fixed cost,
or roughly 47 percent slower. Every process run has the same direction. LDC
therefore provides clear evidence against runtime prepared coefficient state for
this fixed-convolution family.

## 16. M4.6 production decision

The final decision is:

~~~text
DO NOT PROMOTE prepared runtime coefficient state.
~~~

Specifically:

- DMD shows only noise-level parity between `direct_fixed` and `prepared`;
- LDC makes `prepared` approximately 47 percent slower than `direct_fixed`;
- no public `PreparedConvolution`, `PreparedKernel`, `ConvolutionPlan`, or
  equivalent runtime prepared-coefficient type is justified;
- the production contract remains `FixedConvolutionKernel` plus
  `convolveInto` with compile-time fixed coefficients.

This result reinforces the current use of D compile-time specialization for the
fixed-kernel family rather than adding runtime state without measured benefit.

## 17. Separate M5 performance signal

The same isolation run exposes a different performance question that must not be
misattributed to coefficient preparation.

Median public one-shot versus direct-fixed ratios were:

~~~text
DMD: 10.274735x
LDC: 10.374125x
~~~

This gap lies between the public semantic path and the already-approved
validation-free direct execution shape. It may contain structural preflight,
region validation, injectivity checking, overlap classification, dispatch,
inlining, or compiler-code-generation cost.

It is not evidence for a public prepared-convolution API.

M5 benchmark work should therefore keep at least these cost classes separately
measurable where applicable:

~~~text
semantic/public operation latency
approved hot executor latency
preflight/validation cost
layout specialization cost
numeric kernel cost
~~~

The first follow-up belongs to M5.1 / Issue #115: establish v0.2 benchmark
families with a deliberate separation between public semantic paths and approved
execution kernels.
