# raster-d v0.2 M0.4 — Raster API Family Audit

Status: **M0.4 family audit — proposed names remain provisional**

Baseline:

```text
branch: develop
commit: 430c471a03e091f16236f5b599b6693faf6f1b76
```

Purpose:

- define the v0.2 General Raster Core boundary before new production API work;
- classify candidate API families by responsibility rather than by convenience;
- reconcile the frozen v0.1 contract with established raster-library expectations;
- incorporate concrete imagery-d consumer pressure without leaking image semantics into raster-d;
- identify the D mechanism appropriate to each accepted family;
- make no production API change.

The current caller-visible baseline is inventoried in
`docs/V0_2_PUBLIC_API_INVENTORY.md`.

## 1. Classification vocabulary

Every candidate family is assigned one primary classification:

```text
CURRENT
    already present in the frozen v0.1 public contract or established
    package-internal production machinery.

CORE
    belongs in the generic raster domain and is justified for v0.2 public
    design, subject to its own issue/contract review.

CONVENIENCE
    useful surface built over a CORE/CURRENT primitive without creating a
    second semantic or execution engine.

CONSUMER-DRIVEN
    a concrete downstream pressure exists, but generic raster-core promotion
    still requires evidence from the relevant consumer/adapter/operation.

IMAGERY
    depends on image, channel, colour, radiometric, NoData or other imagery
    semantics and belongs above raster-d.

ADAPTER
    bridges external ownership, decoder/provider memory or foreign APIs without
    becoming generic raster semantics.

REJECT
    intentionally excluded from the raster-d public core under the current
    workspace contract.
```

A family may later move from CONSUMER-DRIVEN to CORE after a separate
evidence-backed design decision. This audit does not make such promotion
implicitly.

## 2. External-reference observations

The audit uses established libraries as evidence for recurring raster concerns,
not as APIs to copy.

### GDAL

GDAL RasterIO demonstrates that a mature raster boundary commonly needs:

- rectangular windows;
- one or more selected bands;
- caller-provided buffers;
- independent pixel/line/band spacing;
- explicit type conversion;
- optional resampling when source and destination sizes differ;
- block-oriented access as a performance consideration.

Reference:

https://gdal.org/en/stable/api/gdaldataset_cpp.html

This supports raster-d's existing Region2D, plane, stride, conversion and
destination-oriented direction. It does **not** justify coupling generic raster
semantics to GDAL datasets, driver policy or block geometry.

### OpenCV

OpenCV Mat exposes cheap ROI/header views and distinct families for copy,
conversion, masked operations, filtering and resizing. Its allocating
`copyTo`/`convertTo` convenience model is useful evidence that convenience
surfaces can coexist with lower-level destination reuse.

Reference:

https://docs.opencv.org/doc/doxygen/html/d3/d63/classcv_1_1Mat.html

Raster-d should retain explicit ownership and no-hidden-allocation semantics
rather than adopting OpenCV's allocation behavior wholesale.

### libvips

libvips demonstrates:

- region-based processing for images larger than memory;
- demand-driven pipelines;
- local-window operations such as convolution;
- separate statistics/resampling operation families;
- internal demand-geometry and threaded execution policy.

References:

https://www.libvips.org/API/8.17/how-it-works.html
https://www.libvips.org/

The region/dependency evidence supports raster-d's internal streaming model.
The automatic scheduler/thread-pool model is **not** a raster-d public API
precedent because the workspace contract prefers caller-owned scheduling and no
hidden execution policy.

### Halide

Halide provides strong evidence for separating:

- algorithm/pixel semantics;
- boundary conditions;
- scheduling/vectorization/parallelization.

References:

https://halide-lang.org/docs/tutorial/lesson_05_scheduling_1.html
https://halide-lang.org/docs/tutorial/lesson_09_update_definitions.html

Raster-d should similarly keep semantic operation families independent from
compiler/layout/scheduler specialization.

## 3. Concrete imagery-d consumer pressure

The accepted imagery-d boundary is:

```text
imagery-d
    |
    v
 raster-d
```

Concrete imagery-d evidence confirms that raster-d already owns the generic
representation, lifetime, ROI, plane/stride, retained storage and generic
operation mechanics.

Imagery-d explicitly keeps the following above raster-d:

- channel roles and names;
- colour semantics;
- alpha meaning;
- image/radiometric scale and offset;
- image NoData meaning;
- imagery-specific validity semantics;
- imagery source/cache policy;
- mosaics, pyramids and image products;
- colour/radiometric normalization.

Current imagery-d pressure cases that may eventually require generic raster
handbacks are narrower:

1. arbitrary external retained-resource adoption;
2. multi-resource public import for independently owned planes;
3. possible promotion of generic dependency/halo contracts;
4. possible generic logical-placement wrapper;
5. possible generic mask/validity association if demonstrated outside imagery.

Those are treated below as ADAPTER or CONSUMER-DRIVEN, not silently promoted.

## 4. v0.2 gap matrix

| Candidate family | Classification | Current evidence / gap | v0.2 direction | D mechanism |
| --- | --- | --- | --- | --- |
| retained ownership / lease / import | CURRENT | v0.1 already distinguishes OwnedByteResource, RasterLease, views and retained import | preserve one ownership architecture | ordinary types + traits/constraints |
| owning `Raster!T` | CORE | ergonomic owner absent; Issue #89 | design as a façade over existing backing/lease model, not a second owner | ordinary template type |
| allocate/adopt/wrap/clone construction family | CORE | public malloc adoption exists; allocation/wrap/clone family incomplete | make ownership transition explicit and testable | ordinary functions/templates; runtime sizes/layout |
| arbitrary foreign release-callback adoption | ADAPTER | imagery pressure case exists; current public path only malloc/free-compatible | add only when a real decoder/adapter proves zero-copy value | explicit @system/@trusted adapter boundary |
| independently owned multi-resource import | ADAPTER | internal backing can represent it; public import is single-resource | defer until concrete adapter evidence | ordinary template/API; no metaprogramming trick |
| read view / writable view | CURRENT | already distinct capabilities | retain distinction; do not collapse with `inout` | ordinary template types |
| ROI / subregion | CURRENT | O(1), lease-bound, checked | normalize naming/UFCS only if compatibility plan permits | ordinary function/member semantics |
| plane view | CORE | logical planes exist but ergonomic public plane-view family absent | expose only if it reduces repeated plane-index plumbing coherently | ordinary lightweight view |
| row view | CONVENIENCE | row access is useful but not a separate ownership concept | build over validated view/plane semantics; avoid making layout promises accidentally | ordinary slice/view where legal; runtime row index |
| same-type copy | CURRENT | qualified v0.1 primitive | reconcile into v0.2 `copyInto` family while preserving overlap contract | ordinary template over T |
| fill | CURRENT | qualified v0.1 primitive | reconcile naming/UFCS with destination-oriented family | ordinary template over T |
| allocating copy/clone | CONVENIENCE | explicit deep copy absent | implement over allocation + copy primitive | ordinary function; allocation explicit |
| same-type point transform | CURRENT | fixed public compile-time transform exists | generalize semantics/name toward `transformInto` | alias template + constraints |
| generic `transformInto` | CORE | Issue #95 | canonical one-input pointwise primitive | alias template; static if only for real capability differences |
| allocating transform | CONVENIENCE | Issue #96 | wrapper over `transformInto`, never second engine | ordinary wrapper/template |
| two-input zip transform | CORE | missing; Issue #97 | generic pairwise elementwise foundation | alias template + two source views |
| arithmetic wrappers | CONVENIENCE | add/sub/mul/div absent | thin semantic wrappers over transform/zip-transform | templates; no duplicate dispatch |
| strict float->double sum | CURRENT | numerically qualified v0.1 primitive | retain as evidence/compatibility while generic reduction family is designed | ordinary function |
| generic reductions | CORE | min/max/minMax/count/mean absent | define failure/empty/NaN/overflow/order before implementation | ordinary templates/traits; runtime plane |
| variance/stddev | CONVENIENCE | useful but not core until base numerical policy settled | later wrappers/families after generic reduction semantics | ordinary templates |
| exact ubyte->float conversion | CURRENT | qualified v0.1 primitive | preserve as compatibility/evidence during policy generalization | ordinary function |
| conversion policy model | CORE | ad-hoc growth would be incoherent | explicit exact/checked/saturating/narrowing/rounding policies only when specified | policy type/enum/template as semantics require |
| generic `convert...Into!To` | CORE | Issue #105 | destination-oriented conversion primitive | template on To/from T + constrained policy |
| allocating conversion | CONVENIENCE | Issue #106 | wrapper over Into form | ordinary template wrapper |
| image normalization / scale-offset conversion | IMAGERY | depends on radiometric/image meaning | keep above raster-d | imagery-d operation |
| generic mask raster storage | CURRENT | a mask can already be an ordinary RasterView!ubyte or other legal T | no special storage type required | existing raster types |
| mask association / validity propagation | CONSUMER-DRIVEN | imagery has a real use, but generic association remains unproven | do not introduce MaskedRaster yet; require non-image evidence or generic operation need | ordinary composite type if promoted later |
| NoData semantics | IMAGERY | imagery-d owns image NoData interpretation | keep out of raster-d core | imagery metadata/policy |
| fixed 3x3 neighbourhood | CURRENT | qualified public v0.1 primitive | retain as evidence while generalizing | alias template |
| generic fixed-shape neighbourhood | CORE | Issues #108-110 | destination-oriented generic primitive with explicit halo contract | compile-time shape where it removes runtime work |
| border policy: valid/constant/clamp/mirror/wrap | CORE | missing public generic policy; Issue #111 | define independently of imagery | small policy type/template; static specialization only if measured |
| imagery-specific edge interpretation | IMAGERY | may depend on product/image semantics | keep above generic border mechanics | imagery policy |
| generic convolution | CORE | missing; Issue #112 | build on generic neighbourhood machinery | kernel template/data + Into API |
| prepared convolution state | CONSUMER-DRIVEN | only useful if reuse amortizes preparation | admit only after measured break-even evidence | prepared type only if qualified |
| nearest/bilinear raster resampling | CONSUMER-DRIVEN | generic use is plausible and Issue #114 exists, but numerical/grid contract is not yet audited | research first; promote to CORE only after generic semantics are proven | destination-oriented API; runtime geometry/policy; compile-time specialization only if measured |
| colour-aware/gamma-aware resampling | IMAGERY | depends on colour/radiometry | keep above raster-d | imagery/color layer |
| request/dependency geometry | CURRENT | package-internal M1 production machinery exists | preserve semantics; public promotion only with consumer need | ordinary value types + pure checked functions |
| materialization planning | CURRENT | package-internal | keep internal unless public consumer contract becomes necessary | ordinary structs/functions |
| retained store / residency accounting | CURRENT | package-internal | remain internal control-plane machinery | templates for caller key/hash where already justified |
| public source/provider abstraction | CONSUMER-DRIVEN | imagery materialization works without one today | do not freeze until multiple providers require the same generic contract | structural template/trait preferred over inheritance |
| caller-selected block geometry | CONSUMER-DRIVEN | internal resolver accepts caller-described blocks | public only if a real streaming consumer needs it | runtime region/key data |
| hidden global scheduler / worker pool | REJECT | conflicts with caller-owned scheduling rule | do not expose or silently create | none |
| public compiler/ISA/layout switches | REJECT | implementation concern | keep internal | `static if` / internal dispatch only |
| string-mixin-generated operation families | REJECT | no syntax-generation need exists | do not use | none |
| mixin templates for ordinary algorithms | REJECT | templates/functions suffice | only reconsider for genuine repeated declaration structure | none |
| prepared/cached state by default | REJECT | violates evidence rule | one-shot coherent API first; prepared state only after measurement | none until qualified |

## 5. Family-by-family decisions

### 5.1 construction and ownership

**Decision:** CURRENT + CORE extensions.

The existing ownership split is architecturally sound:

```text
OwnedByteResource
    -> retained import
    -> RasterLease!T
    -> RasterView!T / WritableRasterView!T
```

v0.2 may improve ergonomics with `Raster!T`, allocation, wrapping and clone,
but must reuse the same retained backing architecture.

Do not introduce:

- a second owning pixel buffer abstraction unrelated to RasterLease;
- hidden deep copy on lightweight view copy;
- source/provider handles as ownership substitutes.

External callback adoption and multi-resource import remain ADAPTER work until
real zero-copy consumers justify them.

### 5.2 views, ROI, planes and rows

**Decision:** CURRENT + CORE/CONVENIENCE ergonomics.

Read-only and writable views remain separate capabilities.

ROI remains a zero-copy checked view transformation.

A plane family is a plausible CORE ergonomic layer because most public
operations currently repeat plane indices. The design must preserve the fact
that planes can be interleaved, strided, negative-stride or shared-resource.

A row family is CONVENIENCE unless it can be defined without accidentally
promising contiguity. A row over a sample-strided plane may be a strided view,
not a D slice.

### 5.3 copy and fill

**Decision:** CURRENT.

The semantics are already generic and proven. M2.5 should reconcile naming and
UFCS with v0.2 destination-oriented conventions, but should not replace these
with a weaker common error model merely for symmetry.

Likely family direction, still provisional:

```d
source.copyInto(destination);
destination.fill(value);
```

Compatibility with the frozen v0.1 names must be explicit.

### 5.4 transform and zip-transform

**Decision:** transform CURRENT -> generalized CORE; zip-transform CORE.

The compile-time callable model is a D strength and already has production
evidence. It should remain the base for generic pointwise operations.

Use templates/traits to express callable legality. Use `static if` only when a
real capability or code-generation difference exists.

Do not generate operation families with string mixins.

Arithmetic should be wrappers over this family, not separate execution engines.

### 5.5 reductions and statistics

**Decision:** CORE, with one CURRENT seed.

`trySumFloatToDouble` proves strict deterministic reduction is feasible, but
it is not a sufficient numerical policy for all T/accumulator combinations.

Before generalization, define:

- empty-input behavior;
- integer overflow policy;
- floating NaN policy;
- accumulator/result type;
- deterministic evaluation order;
- precision requirements;
- mask/validity interaction only if a generic validity model is later accepted.

`min`, `max`, `minMax`, `count`, `sum` and `mean` are strong generic
raster candidates.

Variance/stddev remain later convenience/statistical extensions.

### 5.6 conversion

**Decision:** CURRENT + CORE policy generalization.

The exact `ubyte -> float` operation remains valid evidence.

v0.2 should not multiply one-off conversion names. A generic conversion family
must first make exact/checked/saturating/narrowing/rounding semantics explicit.

Representation conversion belongs in raster-d.

Image normalization, colour conversion and radiometric scale/offset are IMAGERY.

### 5.7 masks and validity

**Decision:** storage CURRENT; association CONSUMER-DRIVEN; image meaning
IMAGERY.

Raster-d already stores mask data generically.

What is not proven is a universal public relationship:

```text
data raster + validity raster -> MaskedRaster
```

Imagery-d has a concrete primary+validity use case, but its own boundary
research explicitly says this is not yet enough evidence for a generic
raster-d masked-raster type.

Promotion requires either:

- a second non-image consumer such as DEM/scientific grid; or
- a generic raster operation that cannot be expressed coherently without a
  standard validity association.

NoData values and quality-class meanings remain above raster-d.

### 5.8 neighbourhood and convolution

**Decision:** fixed 3x3 CURRENT; generalized family CORE.

The existing 3x3 implementation supplies evidence for:

- halo validation;
- overlap/no-write guarantees;
- arbitrary validated affine layouts;
- compile-time kernels;
- decomposition-independent streamed execution.

The generic design should separate:

```text
neighbourhood geometry
border policy
kernel semantics
destination
execution specialization
```

Compile-time neighbourhood shape is justified only when it removes actual
runtime work/state or materially improves generated code.

Convolution should reuse this family rather than inventing a second spatial
executor.

### 5.9 border handling

**Decision:** CORE generic policy.

`valid`, `constant`, `clamp`, `mirror` and `wrap` are generic raster
concepts when fully specified.

Border policy must remain separate from:

- source materialization;
- provider tile edges;
- logical dataset extent;
- imagery-specific semantic interpretation.

This separation is consistent with raster-d M1 dependency planning and with
Halide-style boundary-condition separation.

### 5.10 resampling

**Decision:** CONSUMER-DRIVEN research candidate.

Nearest and bilinear resampling are plausibly generic for DEMs, scientific
grids, GDAL windows and imagery. However, promotion requires a clear contract
for:

- source and destination coordinate relation;
- sample-center/cell interpretation;
- empty/outside behavior;
- integer/floating conversion;
- accumulator precision;
- border policy;
- aliasing;
- destination reuse;
- layout independence.

Do not let GDAL/OpenCV-style convenience conversion+resampling collapse these
policies into one opaque call.

Gamma-aware, colour-aware or radiometric resampling remains IMAGERY.

### 5.11 streaming and dependency execution

**Decision:** CURRENT internally; public exposure remains CONSUMER-DRIVEN.

The production repository already contains generic request/dependency,
materialization, residency and retained-store machinery.

That does not mean all of it should become public in v0.2.

Public promotion should happen only when a consumer must coordinate these
semantics directly and the contract cannot remain structural/internal.

In particular, keep separate:

```text
semantic request/dependency
resident materialization
retained reuse
source/provider implementation
scheduler/executor ownership
```

A public source interface is not currently required.

## 6. D mechanism audit

### Runtime parameters

Use runtime parameters for values that are ordinary request data:

- regions;
- plane indices;
- source/destination views;
- destination dimensions;
- runtime border constants;
- runtime conversion parameters where semantics require them;
- caller-owned block keys/regions.

Do not template these merely because they are sometimes constant.

### Ordinary templates and traits

Preferred for semantic type/callable families:

- `Raster!T`, views and leases;
- transform callable;
- zip-transform callable;
- destination sample type;
- numeric/sample capability traits;
- fixed-capacity retained-store internals;
- typed conversion policies where type-level selection is semantically useful.

Traits become public only when they describe a real caller-visible capability.

### `static if`

Use only for genuine compile-time differences such as:

- supported type families;
- compiler/backend capability;
- fixed-shape specialization;
- semantically distinct policy implementations;
- measured fast paths.

Do not use `static if` as a substitute for ordinary runtime branching on
request data.

### Mixin templates

Not selected for any v0.2 family in this audit.

They remain available only if later work reveals repeated declaration
structure that normal templates/functions cannot express cleanly.

### String mixins

REJECT for current v0.2 API families.

No accepted family requires generated D syntax.

### Destination-oriented Into APIs

Default performance-oriented form for operations that produce raster output:

- copy;
- transform;
- zip-transform;
- conversion;
- neighbourhood;
- convolution;
- resampling if promoted.

Allocating forms are CONVENIENCE wrappers over the same semantics.

### Prepared state

Not a default API pattern.

Only introduce prepared state where measurements record:

- preparation cost;
- repeated one-shot cost;
- prepared repeated cost;
- break-even reuse count;
- realistic consumer reuse.

This applies especially to convolution and any future resampling/filter plan.

## 7. Naming and UFCS direction

The v0.2 family should follow the workspace-wide convention used by the
Euclidean geometry API family:

- free functions remain canonical for algorithms;
- the first argument should be the natural semantic subject;
- UFCS should emerge naturally;
- names should express semantic operation, not implementation path;
- dimension/layout/compiler/ISA details do not belong in public names unless
  they change semantics.

Provisional examples only:

```d
view.copyInto(destination);
destination.fill(value);

view.transformInto(destination, transform);
a.zipTransformInto(b, destination, transform);

view.sum(...);
view.minMax(...);

view.convertInto!float(destination, policy);

view.applyNeighbourhoodInto!shape(destination, kernel, border);
view.convolveInto(destination, kernel, border);

view.resampleInto(destination, mapping, method, border);
```

These names are **not approved public API** by this audit.

## 8. Explicit rejections

The following do not belong in the v0.2 General Raster Core unless a future
documented exception changes the contract:

- hidden global worker pool;
- implicit background scheduling;
- public compiler switch;
- public ISA switch;
- public internal-layout selector;
- provider tile geometry as processing geometry;
- GDAL driver/source types in the raster core;
- image channel identities;
- RGB/alpha/colour-space semantics;
- radiometric normalization;
- image NoData interpretation;
- implicit gamma-aware resampling;
- automatic cache eviction policy as part of a semantic operation;
- speculative heterogeneous-sample RasterView;
- string-mixin-generated API families.

## 9. Gap summary by milestone

The existing v0.2 issues are consistent with this audit.

### M1 — ownership and views

CORE:

- `Raster!T` owner design;
- coherent allocate/adopt/wrap/clone family;
- ergonomic view/plane/ROI family;
- explicit clone/deep copy;
- UFCS normalization.

### M2 — pointwise operations

CORE:

- generalized transformInto;
- zipTransformInto;
- copy/fill reconciliation.

CONVENIENCE:

- allocating transform;
- arithmetic wrappers.

### M3 — reductions and conversion

CORE:

- reduction policy and sum/min/max/minMax/mean;
- generic conversion policy;
- destination-oriented generic conversion;
- only genuinely useful public sample traits.

CONVENIENCE:

- allocating conversion.

### M4 — spatial operations

CORE:

- generic neighbourhood;
- generic border policy;
- convolution.

CONSUMER-DRIVEN / research-gated:

- prepared convolution state;
- resampling.

### M5 — qualification

No new semantic family is implied by performance work.

M5 remains responsible for:

- comparable benchmarks;
- internal layout specialization;
- DMD/LDC codegen;
- SIMD qualification;
- persistent-worker research under caller-owned scheduling;
- prepared-state qualification;
- C++ comparison gates.

## 10. M0.4 exit decision

The v0.2 General Raster Core boundary is sufficiently defined to permit M1
design work.

The accepted direction is:

```text
PUBLIC GENERIC RASTER CORE
    ownership / retained lifetime
    views / ROI / plane ergonomics
    destination-oriented copy/fill
    transform / zip-transform
    generic reductions
    explicit representation conversion
    neighbourhood / border / convolution

RESEARCH OR CONSUMER-GATED
    external ownership adapters
    multi-resource public import
    mask/validity association
    public source/dependency orchestration
    resampling
    prepared state

OUTSIDE RASTER-D CORE
    image/channel/colour/radiometric semantics
    image NoData meaning
    provider/cache policy
    hidden scheduling
    compiler/ISA/layout API
```

No proposed v0.2 public name in this document is final. Each family still
requires its milestone issue's public-contract review before implementation.

## 11. M0.4 completion checklist

- [x] v0.2 gap matrix exists;
- [x] every required candidate family is classified;
- [x] each accepted family has an explicit rationale;
- [x] D mechanism is identified for accepted families;
- [x] imagery-specific semantics remain outside raster-d;
- [x] adapter-specific semantics remain separate from generic raster semantics;
- [x] streaming/dependency public promotion is evidence-gated;
- [x] scheduling remains caller-owned;
- [x] prepared state remains measurement-gated;
- [x] proposed public names remain provisional;
- [x] no production API change is made.
