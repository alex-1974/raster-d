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
| binary-transform/arithmetic | `zipTransformInto`, `addInto`, `subtractInto`, `multiplyInto`, `divideInto` | qualified |
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
DMD/LDC.

Reference-XPS evidence recorded on 2026-10-06:

~~~text
archive:
    raster-v0.2-binary-transform-arithmetic-20261006-221741.tar.gz

SHA256:
    96e00251d079b3c49ebfa6097d7430bb98e95fcee65153132427aa39163521d8

benchmark head:
    714e808b56b5a8cfb9bc8b53265d1112652b1e13

reference machine:
    Dell XPS 15
    Intel Core i7-9750H
    Linux x86-64
    CPU affinity 0

toolchain:
    DUB 1.40.0
    DMD 2.111.0
    LDC 1.41.0
    D frontend 2.111.0
    LLVM 19.1.7

workload:
    float
    2048 x 512
    32 elements row padding
    Canonical sample stride 1
    8 iterations per timed sample
    18 timed samples per process
    6 independent processes per compiler
~~~

The archive manifest verifies completely. All compared paths retain stable,
operation-specific checksums and unchanged destination padding.

Median ns/sample and paired ratios:

| Compiler | Operation | Public path | Hot executor | Public/executor |
| --- | --- | ---: | ---: | ---: |
| DMD 2.111 | add public zip | 0.480881 | 0.483760 | 0.991960 |
| DMD 2.111 | add wrapper | 0.487226 | 0.483760 | 0.996067 |
| DMD 2.111 | subtract wrapper | 0.541404 | 0.541764 | 0.996800 |
| DMD 2.111 | multiply wrapper | 0.540704 | 0.485399 | 1.113914 |
| DMD 2.111 | divide wrapper | 0.758606 | 0.763014 | 0.995785 |
| LDC 1.41 | add public zip | 0.429830 | 0.440601 | 0.988816 |
| LDC 1.41 | add wrapper | 0.454840 | 0.440601 | 1.029881 |
| LDC 1.41 | subtract wrapper | 0.399736 | 0.421235 | 0.975722 |
| LDC 1.41 | multiply wrapper | 0.467124 | 0.401172 | 1.063160 |
| LDC 1.41 | divide wrapper | 0.396779 | 0.419193 | 0.941382 |

LDC absolute process timings vary materially with machine state, so paired
same-process ratios are used for interpretation. The family shows no M4.6-style
public/preflight/executor cliff.

The DMD multiply wrapper shows a repeatable approximately 11% median overhead
relative to the executor, with LDC around 6%. This is retained as a targeted
M5.3 code-generation/inlining signal rather than interpreted as a separate
public execution engine or as a reason to reject the family qualification.

The binary-transform/arithmetic family is therefore `qualified` for M5.1.

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
