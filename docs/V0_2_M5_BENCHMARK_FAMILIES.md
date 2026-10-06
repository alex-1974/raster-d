# raster-d v0.2 M5.1 — benchmark families

Status: active benchmark-coverage contract for Issue #115.

Baseline:

~~~text
develop
0d03d7539b231129cb92c1641c7196b4196b71c1
~~~

## 1. Goal

M5.1 establishes one explicit benchmark family map for the performance-relevant
v0.2 processing API.

The goal is not one benchmark executable per public symbol. Closely related
operations may share a representative family when they have materially the same
validation, layout, dispatch and kernel structure.

Every family must make clear which cost is being measured.

## 2. Required measurement layers

For performance-sensitive operations, benchmarks distinguish these layers when
the implementation contains them:

~~~text
public_semantic
    complete supported public call
    validation + relation proof + dispatch + execution

preflight
    validation / shape / injectivity / overlap / relation work

hot_executor
    already-qualified execution path after required semantic facts are known

layout_specialization
    cost or benefit of Canonical / Contiguous / Universal selection

numeric_kernel
    arithmetic or memory kernel after semantic and layout decisions
~~~

Not every operation requires five separately timed paths. A layer is timed only
when it is real, independently meaningful and can be isolated without weakening
the semantics of the comparison.

The M4.6 convolution result is the motivating example: one-shot versus
direct-fixed was about 10x on both baseline compilers, while direct-fixed versus
prepared isolated the actual prepared-state question. Mixing those comparisons
would have attributed public preflight cost to coefficient preparation.

## 3. Benchmark-family inventory

The machine-readable inventory is
`benchmark/v0_2_families/families.tsv`.

Current families are:

| Family | Representative public surface | Current state |
| --- | --- | --- |
| reduction | `sum`, `min`, `max`, `minMax`, `mean` | partial |
| unary-transform | `transformInto`, allocated transform wrapper | partial |
| fill-copy | `fill`, `copyInto` | historical executor evidence; v0.2 family gap |
| binary-transform/arithmetic | `zipTransformInto`, `addInto`, `subtractInto`, `multiplyInto`, `divideInto` | partial — retained layered harness; reference-XPS evidence pending |
| conversion | `convertRasterInto`, allocated conversion wrapper | historical exact-conversion evidence; generic v0.2 gap |
| neighbourhood | `applyNeighbourhoodInto`, `convolveInto` | partial |

Trivial metadata accessors, enums, result carriers and compile-time traits do not
receive standalone microbenchmarks.

Ownership/import operations remain outside this processing-family matrix. Their
allocation and construction cost is measured separately when a release claim or
consumer profile makes it material.

## 4. Existing accepted evidence

### Reduction

`benchmark/v0_2_sum` measures the public generic strict sum against the frozen
legacy sum and a strict scalar C++ reference.

This covers the sum member of the reduction family, not extrema or mean.

### Unary transform

`benchmark/v0_2_transform_into` compares the v0.2 public wrapper with the
already-qualified legacy public path. It establishes wrapper overhead evidence.

Historical M3.2b evidence separately characterizes the public transform path and
the approved Canonical executor.

### Binary transform / arithmetic

`benchmark/v0_2_binary_transform_arithmetic` measures one representative
Canonical padded float workload at three relevant layers:

~~~text
generic public zip
public arithmetic wrapper
approved Canonical hot executor
~~~

Addition uses all three paths, so wrapper overhead can be separated from the
larger public-semantic/preflight/dispatch boundary. Subtract, multiply and divide
compare the public wrapper with the same approved Canonical executor shape using
their corresponding numeric operation.

All compared paths for an operation require identical logical checksums and
unchanged destination padding. The harness is retained and compile-smoked under
DMD/LDC; the family remains `partial` until reference-XPS evidence is recorded.

A cross-language reference is intentionally deferred to M5.7 / Issue #121.

### Fill / copy / conversion

BENCHMARK.md retains qualified M3 evidence for their execution forms, relation
checks and compiler-specific conversion paths.

That evidence is still valid provenance for the underlying implementation, but
M5.1 does not silently relabel it as complete v0.2 family coverage. New v0.2
wrappers or generic policies need representative current-family measurements
where their cost can differ.

### Neighbourhood / convolution

`benchmark/v0_2_prepared_convolution` now provides the first explicit M5-style
layer separation:

~~~text
one_shot
    public_semantic

direct_fixed
    hot_executor / numeric_kernel control

prepared
    alternative runtime coefficient-state executor
~~~

The final M4.6 evidence rejects prepared runtime coefficient state and exposes a
separate roughly 10x public-semantic versus direct-fixed question.

## 5. Qualification record

A benchmark result is not accepted as M5 evidence unless its retained record
states at least:

- exact repository baseline commit;
- exact D compiler and version;
- LDC frontend/LLVM version where applicable;
- complete build flags / release configuration;
- CPU/platform and operating system;
- affinity and frequency/thermal controls where used;
- workload shape, sample type and layout;
- warm-up count;
- timed sample count and independent process count;
- median or distribution, not only a single best run;
- semantic preflight / checksum or equivalent correctness proof;
- which measurement layer each timed path represents;
- allocation behavior where material.

Stable reference-XPS timing remains the primary absolute performance evidence.
Hosted CI only compile-smokes benchmark sources unless a relative same-run
comparison is explicitly documented as informational.

## 6. Comparison rules

A public/executor ratio is never automatically a language-performance ratio.

Before interpreting a large gap, identify whether it contains:

- validation;
- shape/region checks;
- injectivity checks;
- overlap/relation classification;
- dispatch/inlining boundaries;
- allocation;
- layout conversion;
- numeric work.

Likewise, a C++ comparison is accepted only when algorithm, precision,
validation, allocation, failure behavior and observable work are documented
closely enough to make the ratio meaningful.

## 7. M5.1 completion gate

M5.1 is complete when:

1. every family row in `families.tsv` is either `qualified` or carries an
   explicit justified `not-applicable` decision;
2. each qualified family has a retained benchmark path and metadata satisfying
   section 5;
3. public-semantic and hot-executor cost are separated wherever both exist and
   the distinction materially affects interpretation;
4. DMD and LDC behavior is recorded separately;
5. CI compile-smokes every retained v0.2 benchmark harness;
6. BENCHMARK.md links the accepted family evidence;
7. Issue #115 is closed only after the coverage matrix contains no unresolved
   `gap` or `partial` row.

This slice establishes the contract and inventory. It does not weaken public
validation, expose internal executors, add hidden scheduling, or create a public
benchmark API.
