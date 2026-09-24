# R0.4 — Execution and Scheduling Research

Status: active research
Date: 2026-09-24
Tracking issue: #10

## 1. Purpose

R0.4 researches the execution layer above raster-d's established raster,
region and dependency semantics.

The immediate R0.4a question is deliberately narrower than selecting a
scheduler:

> What is the smallest generic synchronous execution contract that connects an
> output request, decomposition, dependency derivation, input materialization,
> operation execution and resource release without embedding scheduler,
> provider or image-domain policy into the raster model?

The synchronous baseline is intended to become the semantic reference against
which later parallel execution strategies can be evaluated.

R0.4a does not imply promotion of any research type into the public production
API.

## 2. Established inputs

R0.4 starts from evidence already established elsewhere in raster-d.

### 2.1 Raster ownership and views

The production raster foundation already defines retained backing, leases,
read-only RasterView, WritableRasterView and validated affine layouts.

Execution research must preserve those ownership and lifetime guarantees.

It must not weaken borrow lifetime or manufacture storage lifetime through an
execution abstraction.

### 2.2 Internal execution layout

`docs/architecture/raster-execution.md` defines the internal per-plane
execution-layout model:

```text
Universal
Canonical
Contiguous
```

and the additional contiguous-1D capability used by semantically linearizable
operations.

That execution-layout layer concerns how an already valid RasterView may be
executed efficiently.

It is not a scheduler.

In particular, it does not define:

- region-task scheduling;
- worker pools;
- cancellation;
- priority;
- cache policy;
- provider policy;
- pipeline parallelism.

### 2.3 R0.3 region and dependency evidence

R0.3 established research evidence for:

- logical output requests;
- decomposition into processing regions;
- spatial dependency derivation;
- neighbourhood/halo requirements;
- decomposition-independent results;
- bounded raster residency;
- procedural source independence.

R0.4 must preserve those properties.

Two R0.3 distinctions remain explicit:

```text
output request != scheduler task
decomposition != scheduler policy
```

An output request is not a scheduler task.

The central correctness rule remains:

```text
legal decomposition must not change the semantic result
```

subject only to any explicitly documented numerical tolerance of the
operation itself.

## 3. R0.4a scope

R0.4a investigates synchronous execution only.

Conceptually, the baseline sequence is:

```text
output request
      |
      v
decomposition
      |
      v
dependency derivation
      |
      v
required-input materialization
      |
      v
operation execution
      |
      v
work-unit completion / failure
      |
      v
release of no-longer-needed resident resources
```

This sequence is conceptual research structure.

It is not yet a production API, type hierarchy or call graph.

## 4. Required semantic properties

A satisfactory R0.4a model must preserve or define the following properties.

### 4.1 Decomposition independence

For every legal decomposition of the same request, synchronous execution must
produce the same semantic result as the undecomposed reference operation.

Execution order must not silently become part of operation semantics.

Operations whose numerical semantics are inherently order-dependent must make
that property explicit rather than relying on scheduler accident.

### 4.2 Bounded residency

Execution must not require the complete logical raster to reside in memory.

The model must permit:

- materializing only currently required regions;
- retaining dependency input while it is required;
- releasing resident resources after their final use;
- enforcing an external or internal residency budget in later execution
  strategies.

R0.4a must identify the semantic lifetime of resident inputs even if the first
reference executor is purely synchronous.

### 4.3 Ownership and borrow lifetime

Execution work must not outlive the leases and resources from which its raster
views are derived.

Any future asynchronous or parallel executor will have to preserve the same
property.

R0.4a therefore needs a model that does not depend on synchronous stack
lifetime accidentally providing correctness.

### 4.4 Failure semantics

R0.4a must distinguish at least:

```text
failure before a work unit starts
failure while materializing dependencies
failure during operation execution
failure after partial internal computation but before work-unit completion
```

Research must determine which state transitions are observable and which
partial results, if any, may become valid output.

Operations that promise failure-before-first-write must retain that stronger
contract.

The generic execution layer must not silently weaken operation-specific
transactional guarantees.

### 4.5 Cancellation semantics

Cancellation belongs to R0.4 even though R0.4a is synchronous.

The synchronous baseline should identify where cancellation could be observed
without requiring a particular token, callback or scheduler API.

Candidate observation boundaries include:

```text
before dependency materialization
after dependency materialization
before operation execution
between decomposed work units
before work-unit completion
```

R0.4a must determine which boundaries are semantically necessary.

It must not yet select a public cancellation mechanism.

### 4.6 Scheduler neutrality

RasterView, WritableRasterView and generic operation semantics must not depend
on:

- a thread pool;
- a particular task library;
- work stealing;
- futures/promises;
- an event loop;
- asynchronous I/O;
- a GPU queue.

A later scheduler should execute an established work contract rather than
define raster semantics.

### 4.7 Provider neutrality

The execution contract must not assume that required input comes from:

- RAM;
- a file;
- GDAL;
- a codec;
- a network service;
- a tile server;
- a procedural source.

R0.6 will research the external source/adapter boundary separately.

R0.4 may require the concept of materialization, but it must not define
provider-specific acquisition policy.

### 4.8 Image-domain neutrality

R0.4 belongs to generic raster execution.

It must not introduce:

- colour semantics;
- radiometric policy;
- image pyramids;
- imagery-specific source priority;
- display-oriented scheduling;
- imagery-specific cache policy.

Those concerns belong to higher-level consumers such as imagery-d.

## 5. Candidate conceptual entities

The following names are research vocabulary only.

They are not proposed public API names.

### Execution request

A request to produce a logical output region for one operation or operation
stage.

### Work unit

One decomposed piece of executable raster work.

A work unit may eventually need to identify:

- its output region;
- its required input regions;
- the operation to execute;
- resources retained for its lifetime.

Whether those properties belong in one value or several cooperating values is
an open question.

### Materialized input

Resident raster data satisfying one dependency requirement for one work unit.

The distinction between:

```text
mathematical dependency
```

and:

```text
currently resident materialization
```

must remain explicit.

### Completion

A state in which a work unit's output is valid according to the operation
contract.

Completion must not merely mean that a function returned.

### Release point

The earliest point after which a resident resource is no longer required by
the current execution plan.

R0.4a must determine whether release points can be derived locally for a
synchronous sequence or require explicit dependency-use accounting.

## 6. Questions R0.4a must answer

### 6.1 What is the minimum schedulable work description?

Does later scheduling require a generic value containing:

```text
output region
required input regions
operation identity
```

or can execution remain an orchestration protocol over existing region and
dependency values?

The research should prefer the smaller abstraction unless evidence requires a
richer object.

### 6.2 Who owns materialized input lifetime?

Possible models include:

- execution scope retains all required leases directly;
- each work unit retains its own leases;
- a separate residency manager owns materializations;
- materialization returns lease-bound views whose lifetime is externally
  controlled.

R0.4a should establish required semantics before choosing implementation form.

### 6.3 When is output publishable?

The model must determine whether a work unit writes directly into its final
destination or whether some operations require temporary unpublished output.

This is especially relevant to failure and cancellation semantics.

No universal temporary-buffer requirement should be introduced without
evidence.

### 6.4 What ordering constraints are semantic?

Independent point operations may permit arbitrary work-unit order.

Neighbourhood operations may impose dependency requirements without imposing
an execution order.

Stateful or reduction-like operations may require stronger rules.

R0.4a must distinguish:

```text
spatial dependency
execution dependency
execution order
```

and must not collapse them into one concept.

### 6.5 What does bounded residency require from execution?

R0.3 demonstrated bounded-residency processing.

R0.4a must identify the execution-side information required to preserve that
property.

Possible requirements include:

- explicit materialization lifetime;
- reference/use counting;
- dependency-consumer accounting;
- ordered release;
- execution-window planning.

These remain hypotheses until tested.

## 7. Initial synchronous reference model

The first model to test should be intentionally simple.

For each work unit in a deterministic sequence:

```text
1. derive required input
2. materialize required input
3. validate execution preconditions
4. execute operation
5. establish work-unit completion according to the operation contract
6. make the completed result available to the research orchestration
7. release work-unit-local inputs no longer required
```

This is the reference model to investigate, not an implementation commitment.

Its purpose is to make lifecycle and failure semantics visible before
parallelism obscures them.

## 8. R0.4a evidence plan

The first research pass should answer the semantic questions on paper using
the existing R0.3 experiments wherever possible.

A new executable experiment is justified only where analysis cannot establish
the required contract.

If an experiment becomes necessary, it should test at least:

- whole versus decomposed synchronous equivalence;
- deterministic work order versus alternate legal work order;
- peak resident input;
- release after final dependency use;
- materialization failure;
- operation failure;
- cancellation at defined observation boundaries;
- empty output requests;
- nonzero logical origins;
- neighbourhood/halo dependencies.

Any experiment must use deterministic synthetic data before introducing an
external raster source.

## 9. Deferred R0.4 questions

The following remain explicitly outside R0.4a:

### R0.4b — region-level parallel execution

Potential topics:

- worker pools;
- independent work units;
- bounded parallelism;
- result equivalence with synchronous execution.

### R0.4c — scheduling policy

Potential topics:

- priority;
- fairness;
- interactive versus throughput work;
- starvation avoidance.

### R0.4d — pipeline execution

Potential topics:

- decode/materialize/compute separation;
- pipeline backpressure;
- staged concurrency.

### R0.4e — advanced scheduling

Potential topics:

- work stealing;
- prefetch;
- dynamic dependency readiness;
- cancellation propagation across active work.

These slice names are provisional research organization only.

## 10. Explicit non-goals

R0.4a does not:

- implement a production scheduler;
- select a concurrency library;
- introduce threads;
- introduce async/await semantics;
- define the R0.6 source/provider API;
- define cache-block policy;
- promote R0.3 research types into the public API;
- change RasterView ownership semantics;
- introduce image semantics;
- design GPU execution.

## 11. R0.4a exit criteria

R0.4a is complete when the research can state, with supporting evidence:

1. the minimum semantic unit of executable raster work;
2. how dependencies become resident inputs;
3. how resident-input lifetime ends;
4. when output becomes valid;
5. how failure affects output validity;
6. where cancellation may be observed;
7. which ordering constraints are semantic and which are scheduler policy;
8. why the model can later support parallel execution without changing raster
   semantics.

Completion of R0.4a does not by itself authorize a production API.

## 12. Current open questions

The first analysis should resolve these questions before implementation:

1. Can the existing R0.3 decomposition/task research already serve as the
   minimum work-unit model?
2. Does bounded residency require explicit final-use accounting, or is lexical
   synchronous lifetime sufficient for the baseline?
3. Must result publication be represented separately from operation execution?
4. Which cancellation boundaries are required by semantics rather than merely
   useful to one scheduler?
5. Which operation classes require ordering beyond spatial dependencies?
6. Can the synchronous baseline be expressed entirely with disposable research
   types?
7. What evidence would justify promotion of any execution concept into the
   production raster API?

## 13. Initial evidence analysis

This section evaluates the open R0.4a questions against evidence already
established by R0.3 and the existing raster execution architecture.

It distinguishes established evidence from R0.4a hypotheses.

### 13.1 Minimum work description

Status: **sufficient for R0.4a without a new production type**

R0.3 already distinguishes:

```text
output request
decomposition member / processing region
spatial dependency
resident materialization
future processing task
```

It also explicitly states:

```text
output request != scheduler task
decomposition != scheduler policy
```

E3.3 nevertheless demonstrated a complete synchronous per-task sequence:

```text
output task
    -> dependency derivation
    -> valid logical input
    -> resident materialization
    -> logical/resident mapping
    -> operation execution
    -> result reassembly
```

R0.4a therefore does not need to invent a new public `ExecutionRequest`,
`Task`, graph or scheduler object.

For the synchronous research baseline, one disposable work description may
simply associate:

```text
one processing/output region
operation/dependency semantics
```

with materialization and execution performed by orchestration around that
description.

A richer schedulable object should be introduced only if later parallel
research demonstrates that it is required.

### 13.2 Resident-input lifetime

Status: **synchronous baseline established; shared lifetime remains open**

E3.2 explicitly used sequential materialization lifetime:

```text
derive dependency
    ->
materialize source
    ->
allocate destination
    ->
execute
    ->
reassemble
    ->
release task source/destination
    ->
process next task
```

This is direct evidence that the synchronous reference executor can bound
resident raster memory by work-unit scope.

R0.4a therefore does not need reference counting, final-use graphs or a cache
ownership model merely to establish the synchronous baseline.

The required baseline semantic rule is:

> A work unit retains every materialization required for its execution and
> releases work-unit-local materializations after that unit no longer needs
> them.

This does not establish the correct lifetime mechanism for:

- shared materializations;
- cache reuse;
- multiple concurrent consumers;
- parallel work units;
- prefetch.

Those require later execution/cache research.

The baseline should describe work-unit lifetime semantically rather than rely
on accidental local-variable or stack lifetime.

### 13.3 Output publication

Status: **not established by R0.3**

E3.2 and E3.3 reassemble completed task results into a test-oracle buffer.

That buffer is explicitly not a proposed production output representation.

Therefore the existing evidence does not justify a universal rule requiring:

- temporary task output;
- transactional publication buffers;
- copy-on-commit;
- direct final-output writes.

R0.4a should instead preserve an abstract validity boundary:

```text
operation succeeds
    ->
that work unit's output may become valid
```

How an operation reaches that boundary remains operation-specific.

An operation that already promises failure-before-first-write must retain that
stronger guarantee.

No generic temporary-output requirement should be introduced without evidence.

A focused R0.4a experiment is required to clarify request-level validity when
a later work unit fails or execution is cancelled.

### 13.4 Cancellation observation

Status: **not established by R0.3**

R0.3 contains no cancellation contract.

The minimum scheduler-neutral baseline should therefore avoid assuming that
materializers or kernels are interruptible.

The smallest initial cancellation model to test is:

```text
before work unit 1
execute work unit 1 without cancellation observation
before work unit 2
execute work unit 2
...
```

In this model, cancellation is observed between work units.

The baseline does not observe cancellation inside a work unit. A work unit
already in execution is therefore allowed to reach its ordinary completion
boundary before cancellation takes effect.

This is a cancellation-observation rule only. It does not imply transactional
or atomic output semantics.

This model has useful properties:

- it requires no cancellation API inside RasterView;
- it requires no provider cancellation contract;
- it does not make kernels scheduler-aware;
- it creates no new partial-write semantics inside an operation.

It may provide insufficient cancellation latency for large materializations or
large work units.

Therefore later research may add optional observation points:

```text
before materialization
after materialization / before operation
inside a cooperative materializer
inside a cooperative long-running operation
```

Those are responsiveness capabilities, not yet required raster semantics.

### 13.5 Execution ordering

Status: **partly established; explicit order-independence evidence required**

R0.3 established decomposition independence for identity and exact local
neighbourhood processing.

Those experiments use:

- disjoint output regions;
- read-only source dependencies;
- independently materialized task inputs.

This strongly supports an execution model in which these local operations do
not require a semantic ordering between independent work units.

However, decomposition independence is not itself a complete proof that every
legal execution order has been exercised.

R0.4a should therefore explicitly test at least:

```text
forward work-unit order
reverse work-unit order
one deterministic permutation
```

for the same decomposition.

All must produce the same exact result for the selected local operation.

No general order-independence claim is made for every operation class.

In particular:

```text
floating-point reductions
incremental aggregates
stateful operations
multi-stage pipelines
```

may require an operation-specific execution/combine-order contract.

Spatial dependency must remain distinct from execution ordering.

### 13.6 Disposable research types

Status: **established**

R0.3 already requires experimental region, dependency, decomposition and
streaming types to remain disposable until separately promoted.

R0.4a should follow the same rule.

The first synchronous executor experiment may therefore use research-local
types even if their names or shapes are unsuitable for production.

Successful use in one experiment is not promotion evidence by itself.

### 13.7 Promotion evidence

Status: **existing promotion rule applies, with additional execution evidence**

Any execution concept considered for production must first satisfy the
existing promotion requirements:

1. concrete consumer;
2. stable semantics supported by evidence;
3. compatibility with the raster coordinate model;
4. ownership/lifetime review;
5. compiler-floor verification;
6. public-surface review.

For an execution abstraction, R0.4 adds a further practical requirement:

> The proposed semantic contract should survive more than one execution
> strategy.

In particular, promotion should not occur merely because a concept makes the
synchronous reference executor convenient.

Before a generic execution abstraction becomes public, later R0.4 evidence
should show that the same semantic contract can support at least:

```text
synchronous sequential execution
and
bounded parallel region execution
```

without changing RasterView semantics or introducing provider/image policy.

## 14. R0.4a evidence still required

The existing evidence eliminates the need for a broad scheduler prototype.

The remaining R0.4a experiment can be narrow.

It should test one disposable synchronous executor using existing R0.3-style
geometry and deterministic synthetic input.

### 14.1 Required cases

The experiment should verify:

```text
whole versus decomposed equivalence
forward task order
reverse task order
deterministically permuted task order
bounded work-unit-local residency
release work-unit-local residency before processing the next task
empty output request
non-zero logical origin
neighbourhood / halo input
materialization failure
operation failure
cancellation between work units
```

### 14.2 Output-validity questions

The experiment must explicitly distinguish:

```text
completed work-unit output
current incomplete work-unit output
complete requested output
```

It should determine which of these remain valid or observable after:

```text
materialization failure
operation failure
cancellation
```

The experiment must not silently equate a partially completed request with a
successfully completed request.

### 14.3 What the experiment does not need

The experiment does not require:

```text
threads
worker pool
futures
async I/O
cache blocks
provider tiles
work stealing
priority
prefetch
production scheduler types
```

If the synchronous model cannot be expressed without one of those concepts,
that is itself evidence that the proposed R0.4a contract is too broad or
incorrectly factored.

## 15. R0.4a working conclusion

The current evidence supports the following provisional execution model:

```text
request
    ->
legal decomposition
    ->
for each work unit:
    observe cancellation
    derive dependency
    materialize work-unit input
    execute operation
    establish work-unit completion
    expose/reassemble valid work-unit result
    release work-unit-local residency
    ->
request completion
```

This model is intentionally sequential.

Its purpose is to define execution semantics, lifetime and validity before
parallel scheduling is introduced.

The unresolved research question is no longer whether raster-d needs a
scheduler abstraction.

The immediate question is narrower:

> Can this synchronous work-unit lifecycle preserve R0.3 correctness and
> bounded residency while giving failure, cancellation and output validity
> precise scheduler-independent semantics?
