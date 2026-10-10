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
| reduction | `sum`, `min`, `max`, `minMax`, `mean` | qualified |
| unary-transform | `transformInto`, allocated transform wrapper | qualified |
| fill-copy | `fill`, `copyInto` | qualified |
| binary-transform/arithmetic | `zipTransformInto`, `addInto`, `subtractInto`, `multiplyInto`, `divideInto` | qualified |
| conversion | `convertRasterInto`, `tryConvertAllocated` | qualified |
| neighbourhood | `applyNeighbourhoodInto`, `convolveInto` | qualified |

Trivial metadata accessors, enums, result carriers and compile-time traits do not
receive standalone microbenchmarks.

Ownership/import operations remain outside this processing-family matrix. Their
allocation and construction cost is measured separately when a release claim or
consumer profile makes it material.

## 4. Existing accepted evidence

### Reduction

`benchmark/v0_2_sum` measures the public generic strict sum against the frozen
legacy sum and a strict scalar C++ reference.

`benchmark/v0_2_reduction_family` covers the remaining extrema/mean members.
For min/max/minMax it compares public result-carrier wrappers against the shared
package `executeExtrema!(mode)` semantic engine. It also records separate
public min + max as an informational two-pass control for one-pass minMax.
For mean it compares public `mean!(double,double)` with the exact explicit
`sum!double + one division` composition that defines the implementation
contract.

Reference-XPS evidence recorded on 2026-10-07:

~~~text
archive:
    raster-v0.2-reduction-family-20261007-110540.tar.gz

SHA256:
    9dcb6116d4143434210182c053a443d613392f859d8ce9c7448b4887639d0f3b

benchmark head:
    732119f87d222a45625e759c602ec99786e93523

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
    source row padding 32 elements
    Canonical sample stride 1
    6 warmups
    18 timed samples per process
    16 iterations per timed sample
    6 independent processes per compiler
~~~

The archive contains 51 tar members. Its recursive SHA256 manifest verifies all
47 retained files other than SHA256SUMS itself. Each public/semantic pair is
bit-equal during semantic preflight. The timed checksum accumulator resolves to
zero for every path because the per-sample checksum is XOR-folded over an even
number of timed samples; semantic equivalence therefore rests on the explicit
preflight plus the retained per-process timing records rather than on the final
zero aggregate alone.

Retained medians and paired ratios:

| Compiler | Operation/path | ns/sample | paired ratio |
| --- | --- | ---: | ---: |
| DMD 2.111 | min public | 2.459261 | public/semantic 0.988719 |
| DMD 2.111 | min semantic | 2.484605 | — |
| DMD 2.111 | max public | 4.772054 | public/semantic 0.997702 |
| DMD 2.111 | max semantic | 4.778953 | — |
| DMD 2.111 | minMax public | 5.972995 | public/semantic 1.005181 |
| DMD 2.111 | minMax semantic | 5.994698 | — |
| DMD 2.111 | min + max public | 7.305133 | two-pass/minMax 1.219937 |
| DMD 2.111 | mean public | 0.984770 | public/explicit 1.006190 |
| DMD 2.111 | mean explicit sum+divide | 0.968109 | — |
| LDC 1.41 | min public | 2.340852 | public/semantic 0.997985 |
| LDC 1.41 | min semantic | 2.358105 | — |
| LDC 1.41 | max public | 2.797366 | public/semantic 1.012728 |
| LDC 1.41 | max semantic | 2.789799 | — |
| LDC 1.41 | minMax public | 2.102938 | public/semantic 0.999220 |
| LDC 1.41 | minMax semantic | 2.109309 | — |
| LDC 1.41 | min + max public | 5.212049 | two-pass/minMax 2.438111 |
| LDC 1.41 | mean public | 3.457505 | public/explicit 0.995094 |
| LDC 1.41 | mean explicit sum+divide | 3.472351 | — |

Paired ratio ranges remain close to parity for public versus semantic/explicit
comparisons:

~~~text
DMD min:     0.972579 .. 1.003809
DMD max:     0.983869 .. 1.010848
DMD minMax:  0.988635 .. 1.015648
DMD mean:    0.991698 .. 1.029518

LDC min:     0.991549 .. 1.045356
LDC max:     0.996276 .. 1.055612
LDC minMax:  0.975930 .. 1.063586
LDC mean:    0.963784 .. 1.016852
~~~

The one-pass minMax contract is also materially cheaper than two separate
public passes on this reference machine:

~~~text
DMD two-pass/minMax median: 1.219937
LDC two-pass/minMax median: 2.438111
~~~

Absolute compiler behavior is intentionally not collapsed into one language
claim. In particular, DMD is much faster than LDC for the strict-sum-derived
mean workload, while LDC is materially faster for max and minMax. Those
differences are retained as M5.3 compiler/code-generation signals, not as public
wrapper regressions.

Combined with the already-qualified strict-sum evidence, the reduction family is
therefore `qualified` for M5.1.

### Unary transform

`benchmark/v0_2_transform_into` compares the v0.2 public wrapper with the
already-qualified legacy public path. Its retained 2026-10-06 XPS evidence
establishes no material wrapper overhead.

Historical M3.2b evidence separately characterizes the public transform path and
the approved Canonical executor.

`benchmark/v0_2_transform_allocated` covers the remaining convenience layer by
comparing `tryTransformAllocated!transform` with the equivalent explicit
`allocateCompactRaster -> writable view -> transformInto!transform` sequence.
Both paths intentionally include allocation and retained-owner construction.
Reference-XPS evidence recorded on 2026-10-07:

~~~text
archive:
    raster-v0.2-transform-allocated-20261007-085810.tar.gz

SHA256:
    e2b92d48b716dab5dcd655f7c915944392cdf641a818d9d9ae0590c4ce11cc89

benchmark head:
    7e5a2c4452851e1378586d4f23eab644f3f21cbe

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
    source row padding 32 elements
    Canonical source sample stride 1
    6 warmups
    18 rotating timed samples per process
    4 allocations/transforms per timed sample
    6 independent processes per compiler
~~~

The recursive manifest verifies all 47 retained files besides SHA256SUMS.
Both paths retain the same stable checksum:

~~~text
4de576fb40f77507
~~~

Retained medians:

| Compiler | Path | ns/sample | public/explicit |
| --- | --- | ---: | ---: |
| DMD 2.111 | public allocated | 0.959474 | 1.000372 |
| DMD 2.111 | explicit allocate+transform | 0.967597 | — |
| LDC 1.41 | public allocated | 0.200731 | 1.002074 |
| LDC 1.41 | explicit allocate+transform | 0.199360 | — |

Paired ratio ranges are:

~~~text
DMD: 0.997263 .. 1.006638
LDC: 0.992010 .. 1.016866
~~~

Absolute process times vary with machine state, especially one LDC process, but
both paths move together and paired ratios remain centered near 1.0. No material
systematic convenience-wrapper penalty is observed.

Combined with the retained transformInto bridge evidence and M3.2b / ADR 0011
executor evidence, the unary-transform family is therefore `qualified` for
M5.1.

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

### Fill / copy

`benchmark/v0_2_fill_copy` measures the current v0.2 API bridge for both
operations without changing production visibility:

~~~text
fill:
    public v0.2 fill
    legacy public tryFillRasterPlane
    package semantic engine tryFillRasterPlaneScalar

copy:
    public v0.2 copyInto
    legacy public tryCopyRasterPlane
    package semantic engine copySameTypeRasterPlane
~~~

The actual Canonical execution helpers remain private. M5.1 does not expose
them solely for benchmarking. Their execution-level behavior is already covered
by retained M3.3/M3.5 qualification evidence.

The new harness therefore answers the missing v0.2 question: whether the current
public spelling and public error bridge add material cost above the existing
semantic engine.

Reference-XPS evidence recorded on 2026-10-06:

~~~text
archive:
    raster-v0.2-fill-copy-20261006-224753.tar.gz

SHA256:
    31d1210072cc069729a7b0054852562adbec5714ecfed8dec79f4fe498711e8b

benchmark head:
    a3cac473191bcb02222b6bd51f3f3e9d6e8fe524

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
    ubyte
    2048 x 512
    32 elements row padding
    Canonical sample stride 1
    16 iterations per timed sample
    6 warmups
    18 timed samples per process
    6 independent processes per compiler
~~~

The recursive archive manifest verifies all 47 retained files. Every compared
path preserves row padding and produces the same stable operation-specific
checksum:

~~~text
fill: d924c80e436d0383
copy: 76d6d3c997828383
~~~

Retained medians and paired ratios:

| Compiler | Operation/path | ns/sample | public v0.2 / semantic |
| --- | --- | ---: | ---: |
| DMD 2.111 | fill public v0.2 | 0.027529 | 1.005535 |
| DMD 2.111 | fill legacy public | 0.027974 | — |
| DMD 2.111 | fill semantic engine | 0.027423 | — |
| DMD 2.111 | copy public v0.2 | 0.037129 | 1.004333 |
| DMD 2.111 | copy legacy public | 0.036973 | — |
| DMD 2.111 | copy semantic engine | 0.037016 | — |
| LDC 1.41 | fill public v0.2 | 0.027293 | 0.997239 |
| LDC 1.41 | fill legacy public | 0.027342 | — |
| LDC 1.41 | fill semantic engine | 0.027370 | — |
| LDC 1.41 | copy public v0.2 | 0.042728 | 0.997127 |
| LDC 1.41 | copy legacy public | 0.042633 | — |
| LDC 1.41 | copy semantic engine | 0.042798 | — |

Paired public-v0.2 / semantic ratio ranges are:

~~~text
DMD fill: 0.994670 .. 1.009141
DMD copy: 0.997453 .. 1.050954
LDC fill: 0.985225 .. 0.999774
LDC copy: 0.993939 .. 1.002829
~~~

One DMD Copy process is an absolute machine-state outlier: all three Copy paths
slow together, while its paired public/semantic ratio remains close enough to
the rest of the cohort to reject a v0.2-wrapper explanation. No systematic
public-v0.2 or public-error-bridge penalty is observed on either compiler.

Combined with the retained M3.3/M3.5 executor evidence, the fill/copy family is
therefore `qualified` for M5.1.

### Conversion

`benchmark/v0_2_conversion` covers the generic v0.2 exact-policy surface
without exposing private numeric executors.

It separates three comparisons:

~~~text
ubyte -> float:
    public generic convertRasterInto
    public specialized tryConvertUbyteToFloatPlane
    package exact semantic engine

ushort -> float:
    public generic convertRasterInto
    package exact semantic engine

allocated ushort -> float:
    public tryConvertAllocated
    explicit allocateCompactRaster + writable view + convertRasterInto
~~~

The ubyte comparison isolates the generic policy/API spelling from the
already-qualified compiler-specialized M3.5 production path. The ushort pair
exercises the generic exact-policy engine instead of the historical special
case. The allocating pair measures the convenience wrapper against the same
explicit allocation/conversion sequence.

Private execution helpers remain private. ADR 0013 / ADR 0014 and retained M3.5
evidence remain the executor/preflight/code-generation evidence.

Reference-XPS evidence recorded on 2026-10-07:

~~~text
archive:
    raster-v0.2-conversion-20261007-082153.tar.gz

SHA256:
    bda1844b8f4f9da2d58a15f26938469c8648c48b3ed06c635549bc9bc94dbbbe

benchmark head:
    ce69499c99b9eedc300297f1622a6ed314de04f5

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
    2048 x 512
    32 elements row padding for destination-oriented paths
    Canonical sample stride 1
    6 warmups
    18 timed samples per process
    6 independent processes per compiler
    16 iterations per destination-oriented timed sample
    4 iterations per allocating timed sample
~~~

The recursive manifest verifies all 47 retained files besides SHA256SUMS.
Destination-oriented paths preserve row padding. Stable per-pair checksums are:

~~~text
ubyte -> float:  8fd9fae9d49d0383
ushort -> float: ecfb68c3e2e5a583
~~~

Retained medians and paired ratios:

| Compiler | Pair/path | ns/sample | paired ratio |
| --- | --- | ---: | ---: |
| DMD 2.111 | ubyte->float public generic | 0.335947 | generic/specialized 0.998153 |
| DMD 2.111 | ubyte->float public specialized | 0.342338 | specialized/semantic 1.004943 |
| DMD 2.111 | ubyte->float semantic engine | 0.337945 | generic/semantic 1.003086 |
| DMD 2.111 | ushort->float public generic | 3.800347 | generic/semantic 1.017085 |
| DMD 2.111 | ushort->float semantic engine | 3.790440 | — |
| DMD 2.111 | allocated public | 3.759492 | public/explicit 1.009449 |
| DMD 2.111 | allocated explicit | 3.692126 | — |
| LDC 1.41 | ubyte->float public generic | 0.159982 | generic/specialized 0.976328 |
| LDC 1.41 | ubyte->float public specialized | 0.162438 | specialized/semantic 1.013020 |
| LDC 1.41 | ubyte->float semantic engine | 0.159167 | generic/semantic 0.991100 |
| LDC 1.41 | ushort->float public generic | 3.156083 | generic/semantic 0.996644 |
| LDC 1.41 | ushort->float semantic engine | 3.148349 | — |
| LDC 1.41 | allocated public | 3.093498 | public/explicit 1.009841 |
| LDC 1.41 | allocated explicit | 3.062337 | — |

The generic public exact-policy API therefore adds no material systematic cost
above the relevant semantic engine on either compiler. The allocating wrapper is
likewise within about one percent of the equivalent explicit allocation and
conversion sequence.

Absolute generic ushort->float throughput is much slower than the specialized
ubyte->float path, but this benchmark does not establish an apples-to-apples
language or algorithm ratio: the type pair and internal execution path differ.
That throughput question remains appropriate for M5.3/M5.4 codegen/layout work
and the comparable C++ gate in M5.7 rather than being attributed to the v0.2
policy or wrapper layer.

The conversion family is therefore `qualified` for M5.1.

### Fill / copy / conversion

BENCHMARK.md retains qualified M3 evidence for their execution forms, relation
checks and compiler-specific conversion paths.

That evidence is still valid provenance for the underlying implementation, but
M5.1 does not silently relabel it as complete v0.2 family coverage. New v0.2
wrappers or generic policies need representative current-family measurements
where their cost can differ.

### Neighbourhood / convolution

`benchmark/v0_2_neighbourhood_family` covers the missing generic neighbourhood
surface without widening private production visibility. It measures the centered
3x3 generic spelling against the preserved legacy public path and the already-
approved package hot executor. It also measures a non-3x3 5x3 shape on both
Canonical unit-sample-stride storage and an equivalent valid sample-strided
signed-affine layout, requiring bit-identical outputs.

The 5x3 private Canonical helper remains private; M5.1 does not weaken
production visibility solely for benchmarking. The layout comparison therefore
measures the real public Canonical versus signed-affine execution forms.

Reference-XPS evidence recorded on 2026-10-07:

~~~text
archive:
    raster-v0.2-neighbourhood-family-20261007-113929.tar.gz

SHA256:
    ff9ca09cefdbe3e39d22e13e4cc1a0ff02279660f2dc0014b501b03838aa62c0

benchmark head:
    a4923a71e5c2df88caefe16e89e43deba27aa829

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
    1024 x 512 output samples
    source row padding 32 physical floats
    3x3 halo 1 sample per side
    5x3 halo 2 horizontal / 1 vertical
    strided sample stride 2
    6 warmups
    18 timed samples per process
    8 iterations per timed sample
    6 independent processes per compiler
~~~

The archive contains 48 files total; its recursive SHA256 manifest verifies all
47 retained files other than SHA256SUMS itself.

Stable semantic checksums:

~~~text
3x3:
    846327cf63eba383

5x3:
    876633b3b2afab83
~~~

Retained medians:

| Compiler | Operation/path | ns/sample | ratio |
| --- | --- | ---: | ---: |
| DMD 2.111 | 3x3 public generic | 76.209098 | generic/legacy 0.996564 |
| DMD 2.111 | 3x3 public legacy | 76.949913 | legacy/hot 16.745190 |
| DMD 2.111 | 3x3 hot executor | 4.590744 | generic/hot 16.575960 |
| DMD 2.111 | 5x3 public Canonical | 120.070195 | — |
| DMD 2.111 | 5x3 public strided | 120.873677 | strided/Canonical 1.007901 |
| LDC 1.41 | 3x3 public generic | 18.295198 | generic/legacy 0.987694 |
| LDC 1.41 | 3x3 public legacy | 18.436974 | legacy/hot 22.287455 |
| LDC 1.41 | 3x3 hot executor | 0.838107 | generic/hot 22.032183 |
| LDC 1.41 | 5x3 public Canonical | 30.057437 | — |
| LDC 1.41 | 5x3 public strided | 30.099535 | strided/Canonical 1.001187 |

Paired process ranges:

~~~text
DMD generic3/legacy3:      0.976221 .. 1.004598
DMD generic3/hot3:        16.384370 .. 16.860886
DMD strided5/Canonical5:  0.997348 .. 1.019196

LDC generic3/legacy3:      0.968464 .. 1.014166
LDC generic3/hot3:        21.399375 .. 22.501127
LDC strided5/Canonical5:  0.992973 .. 1.027238
~~~

Interpretation:

- the generic centered-3x3 public spelling is at parity with the preserved
  legacy public spelling on both compilers;
- the 5x3 sample-strided signed-affine fallback is at parity with the public
  Canonical 5x3 path for this workload;
- the large public-vs-approved-hot-executor gap is reproducible and materially
  larger than the M4.6 convolution public/direct-fixed signal;
- this gap is retained for M5.2/M5.3 investigation and does not indicate a
  generic-wrapper regression, because generic and legacy public paths move
  together;
- no private 5x3 executor visibility was widened for qualification.

Combined with the retained M4.6 convolution isolation evidence, the complete
neighbourhood/convolution family is therefore `qualified` for M5.1.

`benchmark/v0_2_prepared_convolution` provides the convolution-side explicit
M5-style layer separation:

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
