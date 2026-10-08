# raster-d v0.2 M5.6 — prepared-state qualification policy

Status: complete.

## Goal

M5.6 applies one evidence rule to proposed prepared or cached operation state:

> Prepared state is promoted only when total workload cost is lower for a
> realistic consumer reuse profile after preparation cost is included.

This policy is deliberately narrower than general caching or residency.

## Scope distinction

Three concepts must remain separate.

### Compile-time specialization

Types such as `FixedConvolutionKernel` encode invariant information in the D
type/template system and store no runtime prepared state.

This is not a runtime preparation API.

### Prepared operation state

Prepared operation state exists when runtime inputs are transformed once into a
reusable representation whose purpose is to make later invocations cheaper.

Examples would include a hypothetical:

- `PreparedConvolution`;
- `PreparedKernel`;
- `ConvolutionPlan`;
- cached runtime transform coefficients.

These are subject to the M5.6 break-even rule.

### Retained raster/cache state

`RetainedRasterStore` retains owned raster backing under explicit entry and
byte limits. Its purpose is avoiding source rematerialization and preserving
bounded residency.

That is a cache/residency capability, not prepared operator state. Its value is
measured through hit/miss/rematerialization workloads and memory budgets, not
through the operator-preparation equation below.

## Required evidence for prepared operation state

Any future prepared-operation proposal must record all of:

1. preparation cost;
2. repeated one-shot execution cost;
3. repeated prepared execution cost;
4. break-even reuse count;
5. realistic consumer reuse profile;
6. DMD and LDC behavior;
7. semantic equivalence;
8. whether the prepared path is receiving unrelated advantages such as skipped
   validation or a different execution kernel.

A public type is not justified merely because its repeated inner loop is faster.

## Total-cost model

For a reuse count `N`:

`oneShotTotal(N) = N * oneShotCost`

`preparedTotal(N) = preparationCost + N * preparedCost`

When:

`preparedCost >= oneShotCost`

there is no finite break-even.

When:

`preparedCost < oneShotCost`

the approximate break-even count is:

`ceil(preparationCost / (oneShotCost - preparedCost))`

The comparison must isolate preparation itself. If the prepared path also skips
validation, changes layout assumptions, changes the numeric kernel or receives
another execution advantage, a fair control is required before promotion.

## Current candidate inventory

The current v0.2 production tree contains no public prepared-operation type.

The concrete prepared-operation proposal investigated so far is runtime
prepared convolution coefficient state from M4.6 / Issue #113.

No other current transform, arithmetic, reduction, neighbourhood or conversion
family proposes runtime prepared state.

## Prepared convolution evidence

Retained qualification:

- benchmark: `benchmark/v0_2_prepared_convolution`;
- archive:
  `raster-v0.2-prepared-convolution-20261006-213617.tar.gz`;
- SHA256:
  `e432900bdefc0e6b5b4eeca604667b0d06069ff236c3666c14cc02f787185e4b`;
- benchmark head:
  `074c3f9cce2982176268b894e5dbf6e780c88d60`;
- exact output checksum:
  `7596c236fe0ac383`.

The decisive comparison is not public one-shot versus prepared, because that
would mix public structural validation with preparation.

The isolation control is `direct_fixed`: the same validation-free Canonical
execution shape with compile-time fixed coefficients.

### DMD 2.111.0

Reference medians:

- one-shot: 107.191503 ns/pixel;
- direct-fixed: 10.442197 ns/pixel;
- prepared: 10.440517 ns/pixel;
- preparation: 1.165500 ns/prepare;
- direct-fixed / prepared: 1.000142x.

The process ratios cross both sides of 1.0.

Finite break-even values appear only because the measured difference is at
noise level:

- finite runs: 3 of 6;
- median reported break-even: 0.001069 reuses.

This is not a meaningful preparation benefit.

### LDC 1.41.0

Reference medians:

- one-shot: 16.832161 ns/pixel;
- direct-fixed: 1.621008 ns/pixel;
- prepared: 2.382672 ns/pixel;
- preparation: 1.165500 ns/prepare;
- direct-fixed / prepared: 0.680331x.

Prepared execution is about 1.47 times the direct-fixed cost. All six process
runs have the same direction.

No run has a finite break-even.

## Consumer reuse interpretation

The benchmark intentionally favors prepared state:

- preparation is outside the repeated execution loop;
- coefficient conversion is excluded from repeated prepared timing;
- structural public preflight is excluded;
- the workload performs repeated large 1024x512 convolutions;
- six independent CPU-pinned processes are used.

This is already a strong reuse scenario.

Even under that favorable profile:

- DMD shows only parity/noise;
- LDC shows a material regression.

Therefore no realistic larger reuse count rescues this particular prepared
coefficient representation. Preparation cost is not the limiting problem; the
prepared representation itself does not improve repeated execution.

## Production decision

Do not promote runtime prepared convolution coefficient state.

The v0.2 contract remains:

- `FixedConvolutionKernel`;
- `convolveInto`;
- compile-time fixed coefficient specialization;
- one-shot public semantics with approved internal execution specialization.

No public:

- `PreparedConvolution`;
- `PreparedKernel`;
- `ConvolutionPlan`;
- equivalent runtime coefficient cache

is justified.

## Policy for future proposals

A future prepared operation may still be admitted, but only when:

1. a concrete consumer workload demonstrates meaningful reuse;
2. preparation and execution costs are retained separately;
3. a fair non-prepared control uses equivalent validation/layout assumptions;
4. total-cost break-even occurs at a reuse count consumers realistically reach;
5. both baseline compilers are understood;
6. public API complexity is proportional to the measured benefit.

If the evidence fails any of these gates, keep the one-shot API and prefer
compile-time specialization or internal source-form optimization.

## Conclusion

M5.6 establishes a reusable evidence rule rather than a reusable prepared-state
type.

Current evidence supports **no runtime prepared-operation API** in raster-d.

The retained convolution experiment is sufficient to reject the only concrete
prepared-operation candidate currently proposed, while bounded retained raster
storage remains a separate cache/residency concern with its own semantics and
qualification criteria.
