# R0.4 — Execution and Scheduling Research

Status: active research
Date: 2026-09-24
Tracking issues: #10 (R0.4a, closed), #14 (R0.4b, active)

## 1. Purpose

R0.4 researches the execution layer above raster-d's established raster,
region and dependency semantics.

R0.4a is complete and establishes the scheduler-independent synchronous
reference lifecycle.

The active R0.4b question remains narrower than selecting a scheduling policy:

> What is the smallest bounded-parallel region-execution model that preserves
> the R0.4a semantic result, completion, failure, cancellation and residency
> rules while permitting independent work units to execute concurrently?

The synchronous R0.4a baseline remains the semantic oracle against which
bounded-parallel execution is evaluated.

R0.4b does not imply promotion of any research type into the public production
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

## 12. Resolved R0.4a questions

The questions that preceded implementation are resolved by the R0.4a
experiment.

### 12.1 Minimum work-unit model

**Decision:** the existing R0.3 concepts are sufficient for the synchronous
baseline without introducing a new production execution type.

The experiment successfully composed:

```text
processing/output region
operation/dependency semantics
resident materialization
research orchestration
```

without a public `ExecutionRequest`, `Task`, graph or scheduler object.

### 12.2 Resident lifetime

**Decision:** work-unit-local lifetime is sufficient for the synchronous
baseline.

Each non-empty work unit retains its required resident materialization through
operation execution and releases that local residency before another work unit
begins.

The experiment records this explicitly rather than inferring correctness from
lexical scope alone.

No reference-count graph, final-use graph or cache-ownership mechanism is
required for the synchronous baseline.

Shared, cached and concurrent lifetime remain later research topics.

### 12.3 Output publication

**Decision:** R0.4a does not justify a generic output-publication mechanism.

The experiment distinguishes:

```text
completed work-unit output
completed coverage
request completion
termination reason
```

A completed prefix remains observable in research state after a later failure
or cancellation, while the request itself remains incomplete.

This is sufficient to preserve the semantic distinction required by R0.4a.

The evidence does not require a universal:

```text
temporary task-output representation
transactional publication buffer
copy-on-commit rule
direct-final-write rule
```

Operation-specific stronger guarantees remain operation-specific.

### 12.4 Cancellation boundary

**Decision:** the synchronous reference model observes cancellation between
non-empty work units.

Cancellation is checked before the next work unit begins.

An already executing work unit is not interrupted by the baseline.

The experiment verified cancellation:

```text
before the first work unit
after a completed prefix
immediately before the final work unit
```

No RasterView, provider or kernel cancellation API was required.

Finer-grained cooperative cancellation remains an optional later
responsiveness capability rather than a requirement of the R0.4a semantic
baseline.

### 12.5 Execution ordering

**Decision:** execution order is not part of the semantic result for the
selected exact local neighbourhood operation with:

```text
disjoint output regions
read-only input dependencies
independent work-unit materialization
```

The same legal irregular decomposition produced byte-identical output in:

```text
forward order
reverse order
one deterministic permutation
```

and matched one-work-unit execution of the same request.

This does not establish universal order independence.

Reductions, stateful operations, multi-stage pipelines and other operation
classes may still require explicit ordering or combine semantics.

### 12.6 Disposable research types

**Decision:** yes.

R0.4a was expressed entirely with experiment-local execution, failure,
cancellation and accounting machinery.

No experiment type was promoted into `source/raster/`.

### 12.7 Promotion threshold

**Decision:** R0.4a alone does not justify promotion of an execution
abstraction.

The synchronous reference contract must first survive another execution
strategy.

The next relevant evidence is bounded parallel region execution.

Any later production proposal still requires the existing promotion review,
including concrete consumers, ownership/lifetime review, compiler-floor
verification and public-surface review.

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

## 14. R0.4a measured evidence

The narrow synchronous experiment was implemented under:

```text
experiments/r0_4a_synchronous_execution/
```

The experiment reused selected R0.3 research modules directly and unchanged.

Historical R0.3 evidence and production `source/raster/` were not modified.

### 14.1 Reuse feasibility

The sibling-module reuse probe established that R0.4a can compile and consume
the required R0.3 research primitives without copying their implementations.

The existing R0.3 `executeNeighbourhoodTask()` path is retained as an
independent success oracle rather than used as the R0.4a lifecycle under test.

Both DMD and LDC passed the reuse probe.

### 14.2 Successful synchronous execution

The success-path experiment used:

```text
non-zero logical origin
exact weighted 3 x 3 neighbourhood operation
one-work-unit execution
one irregular six-member decomposition
forward execution order
reverse execution order
one deterministic permutation
```

Results were byte-identical:

```text
whole
==
forward
==
reverse
==
deterministic permutation
```

Every successful work unit reached an explicit completion boundary.

Work-unit-local resident raster accounting returned to zero before the next
non-empty work unit.

### 14.3 Materialization failure

A deterministic materialization failure was injected at work-unit ordinal 3
of a four-member decomposition.

Observed result:

```text
work units considered      = 3
work units started         = 3
work units completed       = 2
materializations started   = 3
materializations completed = 2
operations started         = 2
operations completed       = 2
releases                   = 2
request completed          = false
termination                = failed
final local residency      = 0
```

The completed two-work-unit prefix remained observable in the research
coverage oracle.

The failing work unit and all later work remained incomplete.

### 14.4 Operation failure

A deterministic operation failure was injected at work-unit ordinal 3 of the
same four-member decomposition.

Observed result:

```text
work units considered      = 3
work units started         = 3
work units completed       = 2
materializations started   = 3
materializations completed = 3
operations started         = 3
operations completed       = 2
releases                   = 3
request completed          = false
termination                = failed
final local residency      = 0
```

The failing work unit's source materialization was released even though that
work unit never reached completion.

Later work did not start.

### 14.5 Cancellation

Cancellation was observed only before starting the next non-empty work unit.

Three deterministic cases passed:

| Observation point | Completed work units | Request completed | Final local residency |
| --- | ---: | --- | ---: |
| before work unit 1 | 0 | false | 0 |
| before work unit 3 | 2 | false | 0 |
| before work unit 4 | 3 | false | 0 |

Completed prefix output remained observable in research state.

The not-yet-started work unit was not considered, materialized or executed.

No cancellation observation occurs inside an executing work unit in the
R0.4a baseline.

### 14.6 Empty output

A valid empty output request completed successfully with:

```text
zero executable work units
zero materializations
zero operation executions
zero resident raster bytes
```

No synthetic zero-sized work unit was created.

### 14.7 Compiler verification

At the final R0.4a evidence HEAD, both current compiler families passed the
complete experiment:

```text
DMD: 8 modules passed unittests
LDC: 8 modules passed unittests
```

This is current-family verification.

It is not a compiler-floor audit.

### 14.8 Success-gate result

All thirteen R0.4a experiment success criteria passed.

No production scheduler, cache, provider, image-domain or cancellation API was
introduced.

## 15. R0.4a final conclusion

R0.4a establishes a scheduler-independent synchronous reference execution
model for the tested region-local raster operation:

```text
request
    ->
validate legal decomposition
    ->
for each non-empty work unit:
    observe cancellation before start
    derive spatial dependency
    materialize work-unit-local input
    execute operation
    establish work-unit completion
    expose/reassemble completed work-unit result
    release work-unit-local residency
    ->
request completion
```

The experiment establishes the following baseline semantics:

1. an output request is not a scheduler task;
2. decomposition membership is distinct from execution order;
3. spatial dependency is distinct from execution ordering;
4. successful local work units may execute in different orders when the
   operation semantics permit it;
5. work-unit completion is distinct from complete-request success;
6. completed prefix output may remain internally observable after later
   failure or cancellation;
7. failure stops later work and does not mark the failed work unit complete;
8. cancellation is observed between work units in the synchronous baseline;
9. an already executing work unit is not interrupted by baseline cancellation;
10. work-unit-local resident raster state is released on every tested return
    path;
11. empty output is successful zero-work execution;
12. logical placement remains separate from resident descriptor coordinates.

The experiment does **not** establish a universal transactional-output or
publication-buffer requirement.

It does **not** establish that every raster operation is order-independent.

It does **not** establish shared/cache/concurrent materialization lifetime.

It does **not** define a public scheduler, `WorkUnit`, cancellation token,
task graph or execution framework.

### 15.1 R0.4a decision

R0.4a is **complete**.

Its synchronous work-unit lifecycle is sufficient as the semantic reference
for the next execution-research slice.

The next research step may investigate bounded parallel region execution
against this reference contract.

### 15.2 Promotion decision

**Do not promote the R0.4a research machinery into the production raster API.**

Before any generic execution abstraction is considered for promotion, later
R0.4 evidence should demonstrate that the semantic contract survives at least
one additional strategy, specifically bounded parallel execution, without
changing RasterView semantics or introducing provider/image policy.

The experiment files remain research evidence and disposable implementation
machinery.

## 16. R0.4b bounded parallel execution contract

R0.4b tests whether the scheduler-independent semantics established by R0.4a
survive bounded concurrent execution.

Tracking issue:

```text
#14 research: prove bounded parallel region execution
```

R0.4b is not a scheduler-selection exercise.

It is an execution-semantics experiment.

The central question is:

> Which additional execution-side state is required solely because more than
> one independent work unit may be active at the same time?

The experiment must prefer the smallest disposable research machinery that can
answer that question.

### 16.1 Inherited R0.4a invariants

R0.4b inherits the following rules unchanged:

```text
output request != scheduler task
decomposition != scheduler policy
spatial dependency != execution ordering
work-unit completion != request completion
logical coordinates != resident coordinates
```

The core correctness requirement remains:

```text
legal decomposition must not change the semantic result
```

For operation classes that permit independent work-unit execution, changing
the execution strategy from synchronous to bounded parallel must not change
the result.

R0.4b must not weaken:

- RasterView ownership;
- WritableRasterView ownership;
- lease lifetime;
- dependency semantics;
- halo/context semantics;
- operation-specific failure guarantees.

### 16.2 Initial operation class

The first R0.4b experiment should deliberately reuse the exact local operation
already exercised by R0.4a:

```text
weighted exact 3 x 3 neighbourhood operation
```

The selected operation has:

- disjoint output regions;
- read-only input dependencies;
- independently materializable input regions;
- exact deterministic output;
- no cross-work-unit mutable state.

This is intentionally narrower than claiming that every raster operation is
parallelizable.

The first experiment does not establish parallel semantics for:

```text
floating-point reductions
incremental aggregates
stateful operations
multi-stage pipelines
shared mutable kernels
```

Those operation classes may require additional execution or combination rules.

### 16.3 Research-local work-state vocabulary

R0.4b needs enough vocabulary to observe concurrent execution without
promoting a public task type.

The first experiment may distinguish research-local work states such as:

```text
not started
running
completed
failed
```

These are instrumentation states.

They are not proposed public API states.

A work unit becomes `running` only after the bounded coordinator has admitted
it for execution.

A work unit becomes `completed` only after its operation succeeds and its
result satisfies the same completion boundary used by R0.4a.

A failed work unit never becomes completed.

Cancellation is primarily a request/coordinator state in the first experiment.

A work unit that never starts because cancellation or failure closed the
dispatch gate remains not started rather than becoming a fictitious completed
or failed unit.

### 16.4 Explicit bounded parallelism

Parallelism must be bounded by an explicit experiment parameter:

```text
maxActiveWorkUnits
```

The experiment must make at least the following accounting observable:

```text
currentActiveWorkUnits
peakActiveWorkUnits
workUnitsStarted
workUnitsCompleted
```

At every observable point:

```text
currentActiveWorkUnits <= maxActiveWorkUnits
```

The experiment must prove that parallel execution actually occurred:

```text
peakActiveWorkUnits > 1
```

for parallelism levels greater than one.

The first experiment should test at least two distinct bounds greater than one.

A suitable initial pair is:

```text
maxActiveWorkUnits = 2
maxActiveWorkUnits = 3
```

The decomposition must contain more non-empty work units than either bound.

The experiment must not create one unbounded thread or asynchronous operation
per decomposition member and call the result bounded execution merely because
the operating system happens to serialize some work.

### 16.5 Deterministic concurrency evidence

Correctness tests must not depend on wall-clock timing.

In particular, tests must not use assumptions such as:

```text
sleep 20 ms
therefore another worker must now be active
```

Such tests would be scheduler-, machine- and load-dependent.

Research-only synchronization gates, barriers or equivalent deterministic
coordination may instead be used to prove:

- more than one work unit is concurrently active;
- a chosen set of work units is already running at a failure/cancellation
  observation point;
- a selected completion order differs from decomposition order.

The synchronization mechanism is experiment machinery.

It is not a proposed production scheduler primitive.

### 16.6 Dispatch model

The initial bounded-parallel coordinator may admit new work while:

```text
request termination has not been observed
and
currentActiveWorkUnits < maxActiveWorkUnits
```

The first experiment needs only enough dispatch machinery to maintain the
bound and observe lifecycle transitions.

It does not need to define:

- priority;
- fairness;
- work stealing;
- queue affinity;
- processor affinity;
- prefetch;
- dynamic dependency readiness.

The bounded coordinator may use any disposable research-only concurrency
primitive whose behaviour can be tested deterministically.

The semantic contract must not depend on the identity of that primitive.

### 16.7 Concurrent resident-resource lifetime

R0.4a established work-unit-local resident lifetime for sequential execution.

R0.4b initially extends that rule directly:

> Each running work unit owns or retains every work-unit-local resident
> materialization required by that unit until the unit no longer needs it.

The first experiment should deliberately avoid shared materialization reuse.

Therefore one running work unit's local residency is independent of another
running work unit's local residency.

Research accounting must expose at least:

```text
currentResidentRasterBytes
peakResidentRasterBytes
```

where `currentResidentRasterBytes` is the aggregate work-unit-local resident
raster memory of all currently retained parallel materializations.

The experiment must verify:

```text
currentResidentRasterBytes >= 0
peakResidentRasterBytes >= currentResidentRasterBytes
```

at all observable states, and:

```text
currentResidentRasterBytes == 0
```

after every completed request, failed request and cancelled request.

The experiment should also make visible that peak parallel residency can exceed
the residency of one synchronous work unit.

That is expected and is not itself a violation of bounded residency.

The required invariant is that concurrency and corresponding local residency
remain explicitly bounded.

### 16.8 Shared lifetime remains deferred

The initial R0.4b experiment does not require:

- cache reuse;
- one materialization shared by multiple running work units;
- reference-counted shared input;
- dependency-consumer counting;
- cache eviction;
- prefetch lifetime.

If bounded parallel execution can be proven using independent work-unit-local
materializations, then those mechanisms remain later cache/execution research.

They must not be introduced merely because concurrency makes them conceivable.

### 16.9 Completion order

Decomposition order and completion order are separate concepts.

For the selected independent local operation:

```text
decomposition membership
execution start order
execution completion order
semantic output placement
```

must remain distinguishable.

A work unit's result belongs to its logical output region, not to its position
in a completion sequence.

The experiment must force at least one deterministic case in which completion
order differs from decomposition order.

The result must remain exactly equal to the synchronous R0.4a oracle.

### 16.10 Initial result-reassembly rule

The first R0.4b experiment should avoid introducing concurrent mutation of one
shared output buffer unless that is necessary to answer the research question.

A simple initial research model is:

```text
worker:
    execute one work unit
    produce completed work-unit result

coordinator:
    observe completion
    reassemble that result into the request oracle/output state
```

This isolates concurrent work-unit execution from concurrent result
publication.

It also avoids conflating:

```text
parallel execution semantics
```

with:

```text
shared-output synchronization strategy
```

This is an experimental simplification, not a proposed production requirement.

Later research may compare direct disjoint writes if there is a concrete
reason to do so.

### 16.11 Completed-set semantics

R0.4a failure and cancellation naturally produced a completed prefix because
execution was sequential.

That prefix property must not be generalized to parallel execution.

With bounded concurrency, a request may terminate after work units such as:

```text
0
2
4
```

have completed while another lower-index work unit is still running or has
failed.

R0.4b therefore generalizes research output validity from:

```text
completed prefix
```

to:

```text
completed work-unit set
completed output coverage
```

The experiment must record completed coverage independently of request
completion.

The request is successful only when every required non-empty work unit has
completed successfully.

### 16.12 Request completion

For the first bounded-parallel model:

```text
requestCompleted == true
```

if and only if:

1. every required non-empty work unit completed successfully;
2. no execution failure terminated the request;
3. cancellation did not terminate the request;
4. all work-unit-local resident raster state has been released.

A request with some completed work units is not therefore a completed request.

This rule is unchanged in meaning from R0.4a even though completed work is no
longer necessarily a prefix.

### 16.13 Failure observation

The first experiment should inject one deterministic failure identified by a
stable decomposition/work-unit identity.

Failure injection must not depend on nondeterministic completion ordinal.

For example:

```text
fail decomposition member 3
```

is suitable.

A rule such as:

```text
fail whichever work unit happens to complete third
```

is not suitable for deterministic semantic evidence.

The experiment should separately exercise:

- materialization failure;
- operation failure.

### 16.14 Failure dispatch rule

When the coordinator observes a failure:

```text
stop admitting new work
```

No work unit that is still not started may begin after the failure has been
observed.

The initial R0.4b experiment does not require forced interruption of work units
that are already running.

Already-running sibling work units are allowed to reach their ordinary
operation boundary.

They must then release their work-unit-local residency.

An already-running sibling that succeeds may still become a completed work
unit even though the overall request is already destined to fail.

Therefore after a parallel failure:

```text
completed work != completed prefix
```

and:

```text
completed work != completed request
```

The failed request must retain enough research instrumentation to distinguish
the set/coverage of work that successfully completed.

### 16.15 Failure does not imply rollback

R0.4b must not infer transactional semantics from request failure.

The initial contract does not require:

- rollback of already completed siblings;
- erasure of completed coverage;
- interruption of already-running siblings;
- restoration of prior output bytes;
- atomic request publication.

Operation-specific stronger guarantees remain possible but are not introduced
by generic bounded-parallel execution research.

### 16.16 First failure scope

The initial failure experiment should control concurrency so that the set of
already-running siblings at failure observation is deterministic.

This allows the experiment to answer:

```text
which work was already running?
which work was never started?
which running siblings completed?
was every local materialization released?
```

without relying on operating-system timing.

The first experiment does not need to resolve:

- simultaneous independent failures;
- competing failure reasons;
- first-error ordering policy;
- aggregation of multiple errors.

Those questions should be researched only if later execution strategies need
them.

### 16.17 Cancellation observation

R0.4b preserves the R0.4a principle:

> Cancellation is observed by execution orchestration rather than by
> RasterView or the raster kernel.

The initial parallel coordinator should observe cancellation at dispatch /
coordination boundaries.

Once cancellation is observed:

```text
stop admitting new work
```

Not-yet-started work remains not started.

Already-running work is not required to be interrupted.

It may reach its ordinary completion boundary and must release its local
resident resources.

The overall request remains cancelled and therefore incomplete.

### 16.18 Cancellation while work is active

The experiment must include a deterministic case in which:

```text
peakActiveWorkUnits > 1
```

and cancellation is observed while a known bounded set of work units is
already running.

The test must verify:

- no additional work starts after observation;
- already-running work follows the documented completion rule;
- completed-set/coverage accounting remains valid;
- request completion remains false;
- all local resident raster state is eventually released.

The first experiment must not introduce cancellation checks inside:

- RasterView;
- materialization primitives;
- the neighbourhood kernel.

Finer-grained cooperative cancellation remains a later responsiveness topic.

This research must not select a public cancellation-token API.

### 16.19 Empty output

The R0.4a zero-work rule remains unchanged.

A valid empty request must:

```text
start zero work units
create zero worker activity
materialize zero raster data
execute zero operations
finish with zero local residency
complete successfully
```

No synthetic empty work unit should be submitted merely to exercise the
parallel machinery.

### 16.20 R0.4b experiment architecture

The first experiment should reuse existing evidence rather than copy it.

Preferred dependency direction:

```text
R0.4b experiment
    ->
R0.4a synchronous reference / selected research helpers
    ->
R0.3 region/dependency/neighbourhood research
    ->
production raster-d API
```

Historical R0.3 and R0.4a experiment sources must remain unchanged.

R0.4b may call the R0.4a synchronous execution result as an independent
semantic oracle.

The bounded-parallel lifecycle itself must be new R0.4b research code.

It must not modify the R0.4a executor in order to make the parallel experiment
pass.

### 16.21 Initial fixture

A suitable first fixture should retain the R0.4a geometry style:

```text
non-zero logical origin
interior requested output
full 3 x 3 context
irregular legal decomposition
deterministic procedural ubyte source
exact weighted neighbourhood operation
```

The decomposition must contain enough non-empty members that:

```text
task count > 3
```

and therefore exceeds both initial tested parallel bounds.

The synchronous R0.4a result is the exact output oracle.

### 16.22 Proposed evidence slices

R0.4b should proceed in narrow evidence slices.

#### R0.4b-1 — bounded success path

Prove:

```text
synchronous result == parallel bound 2 result
synchronous result == parallel bound 3 result
peak active > 1
peak active <= configured bound
final resident bytes == 0
```

#### R0.4b-2 — out-of-order completion

Use deterministic research synchronization to force completion order different
from decomposition order.

Prove byte-identical final output.

#### R0.4b-3 — materialization and operation failure

Inject one stable work-unit failure while known siblings are already running.

Prove:

```text
request incomplete
failed unit incomplete
dispatch closes
not-yet-started work remains unstarted
already-running siblings follow the documented rule
all local residency is released
```

#### R0.4b-4 — cancellation with active work

Observe cancellation while a known bounded set of work units is running.

Prove:

```text
request cancelled
dispatch closes
not-yet-started work remains unstarted
already-running work follows the documented rule
all local residency is released
```

#### R0.4b-5 — empty request

Prove successful zero-work execution through the bounded-parallel entry path.

### 16.23 R0.4b hypotheses

The initial hypotheses are:

**H1 — strategy equivalence**

For the selected exact local operation:

```text
synchronous == bounded parallel
```

for at least two parallel bounds greater than one.

**H2 — bounded active work**

Actual overlap occurs, but:

```text
peakActiveWorkUnits <= maxActiveWorkUnits
```

always holds.

**H3 — bounded aggregate residency**

Concurrent resident raster state may exceed one synchronous work unit, but it
remains explicitly measurable, finite and bounded by admitted active work.

Final work-unit-local residency is zero.

**H4 — completion-order independence**

For the selected operation, changing completion order does not change semantic
output.

**H5 — parallel failure cleanup**

Failure closes dispatch, does not complete the failing work unit, does not make
the request complete, permits already-running siblings to follow the documented
rule and eventually releases all work-unit-local residency.

**H6 — parallel cancellation cleanup**

Cancellation closes dispatch, suppresses not-yet-started work, permits
already-running work to follow the documented rule and eventually releases all
work-unit-local residency.

**H7 — no richer public abstraction is assumed**

The experiment can be expressed using disposable orchestration and
instrumentation without changing RasterView or promoting a production
scheduler/work-unit API.

### 16.24 Questions that evidence must answer

R0.4b must answer:

1. Does concurrent execution require a richer semantic work-unit object than
   R0.4a?
2. Is independent work-unit-local retention sufficient for the first bounded
   parallel model?
3. What accounting is required to bound aggregate active residency?
4. Is a coordinator plus bounded workers sufficient for this operation class?
5. Does completion need an explicit stable work-unit identity?
6. How should already-running siblings behave after one failure is observed?
7. How should already-running work behave after cancellation is observed?
8. Is completed-set/coverage sufficient to represent partial internal validity?
9. Does output reassembly remain independent of completion order?
10. Which concepts now have evidence across both synchronous and bounded
    parallel execution strategies?

### 16.25 Explicit non-goals

R0.4b does not select or implement production policy for:

```text
priority
fairness
work stealing
pipeline parallelism
decode/materialize/compute staging
prefetch
async I/O
dynamic dependency readiness
cache blocks
shared cache lifetime
provider/source policy
imagery scheduling
GPU execution
```

It also does not promote:

```text
public Scheduler
public WorkUnit
public Task
public CancellationToken
public execution graph
```

### 16.26 Success gate

R0.4b evidence is sufficient only if all of the following hold:

1. synchronous and bounded-parallel successful output are exactly equivalent
   for the selected operation;
2. at least two parallel bounds greater than one are exercised;
3. actual concurrent overlap is proven without timing assumptions;
4. active work never exceeds the configured bound;
5. deterministic out-of-order completion does not change output;
6. aggregate resident-raster accounting is explicit;
7. final work-unit-local residency is zero on success;
8. final work-unit-local residency is zero after materialization failure;
9. final work-unit-local residency is zero after operation failure;
10. final work-unit-local residency is zero after cancellation;
11. failure suppresses not-yet-started work after observation;
12. cancellation suppresses not-yet-started work after observation;
13. already-running sibling behaviour is explicit and experimentally verified;
14. completed work remains distinguishable from completed request state;
15. empty output remains successful zero-work execution;
16. non-zero logical coordinates remain separate from resident coordinates;
17. historical R0.3 and R0.4a evidence remains unchanged;
18. production `source/raster/` remains unchanged;
19. no scheduling/cache/provider/image policy is promoted;
20. DMD and LDC produce the same deterministic correctness result.

### 16.27 Promotion rule after R0.4b

Passing R0.4b would provide evidence that a common semantic contract survives
two execution strategies:

```text
synchronous sequential
bounded parallel
```

That is stronger promotion evidence than R0.4a alone.

It is still not automatic authorization for a public execution API.

After R0.4b, any proposed production abstraction must be evaluated against:

- concrete raster consumers;
- stable semantics common to both strategies;
- ownership and borrow lifetime;
- aggregate residency requirements;
- compiler-floor compatibility;
- public-surface cost;
- interaction with later scheduling and source research.

If no new public abstraction is required, the correct decision may still be to
keep execution orchestration internal or research-local.
