# R0.4 — Execution and Scheduling Research

Status: active research
Date: 2026-09-24
Tracking issues: #10 (R0.4a), #14 (R0.4b), #16 (R0.4c), #18 (R0.4d, active)

## 1. Purpose

R0.4 researches the execution layer above raster-d's established raster,
region and dependency semantics.

R0.4a, R0.4b and R0.4c are complete as research evidence.

They establish, respectively:

- scheduler-independent synchronous reference semantics;
- bounded parallel execution semantics;
- deterministic ready-work scheduling-policy semantics.

The active R0.4d question is:

> What is the smallest bounded staged raster-execution model that allows
> different work units to occupy different execution stages concurrently while
> preserving the R0.4a/R0.4b/R0.4c semantic reference and making inter-stage
> backpressure, stage ownership and termination cleanup explicit and testable?

The R0.4a synchronous result remains the semantic oracle. R0.4b remains the
bounded-parallel execution reference. R0.4c remains the policy-separation
reference.

R0.4d does not imply promotion of any research type into the public production
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

## 17. R0.4b measured evidence

R0.4b was implemented as disposable research orchestration under:

```text
experiments/r0_4b_bounded_parallel_execution/
```

Evidence commits:

```text
b9f43f5 research: define R0.4b bounded parallel execution contract
5988188 research: define R0.4b parallel execution experiment
ff5da8e research: prove R0.4b reuse of prior execution evidence
b09d75b research: prove R0.4b bounded parallel success
aaceb24 research: prove R0.4b out-of-order completion
3bfa813 research: prove R0.4b parallel failure semantics
6106a32 research: classify R0.4b operation failure explicitly
4a06bc3 research: prove R0.4b parallel cancellation semantics
6c5bf93 research: prove R0.4b empty parallel request
```

Historical R0.3 and R0.4a sources remained unchanged.

Production `source/raster/` remained unchanged.

### 17.1 Strategy-equivalence result

The same exact weighted 3 x 3 region-local operation was executed using the
R0.4a synchronous reference and R0.4b bounded-parallel execution with explicit
bounds 2 and 3.

The successful result was:

```text
R0.4a synchronous
==
R0.4b bounded parallel, bound 2
==
R0.4b bounded parallel, bound 3
```

byte-for-byte.

The six-member irregular decomposition contained more work than either tested
parallel bound.

### 17.2 Concurrent-work result

Research-local barriers established actual concurrent activity without
wall-clock timing.

The successful fixtures proved:

```text
bound 2 -> peakActiveWorkUnits == 2
bound 3 -> peakActiveWorkUnits == 3
```

and therefore:

```text
1 < peakActiveWorkUnits <= maxActiveWorkUnits
```

No `sleep`, timeout or CPU-speed assumption was used to prove overlap.

### 17.3 Concurrent-residency result

The deterministic resident-ready barriers were reached only after each admitted
worker had successfully materialized its required input.

At that observation point the worker-local resident rasters remained alive.

The experiment therefore established genuine concurrent resident raster
lifetime rather than merely concurrent thread lifetime.

For the successful parallel fixtures:

```text
peak parallel resident bytes
>
R0.4a synchronous single-work-unit peak resident bytes
```

and every tested return path ended with:

```text
currentResidentRasterBytes == 0
```

R0.4b establishes explicit aggregate residency accounting.

It does **not** establish that a work-count bound is a general byte-budget
admission policy for heterogeneous future work units.

A later execution/scheduling layer may still require an explicit resident-byte
budget or admission controller.

### 17.4 Completion-order result

R0.4b-2 forced:

```text
decomposition order:
    0, 1

completion/publication order:
    1, 0
```

using deterministic synchronization.

The final output remained exactly equal to the synchronous oracle.

Therefore, for the selected operation:

```text
completion order != semantic output placement
```

Logical output region determines placement.

### 17.5 Materialization-failure result

The deterministic materialization-failure fixture used four legal work units:

```text
0 -> already-running resident sibling
1 -> stable injected materialization failure
2 -> never started
3 -> never started
```

After failure observation:

- dispatch closed;
- work units 2 and 3 never started;
- work unit 1 never became completed;
- work unit 0 was allowed to finish normally;
- completed sibling coverage remained observable research state;
- the request remained incomplete/failed;
- final local residency was zero.

### 17.6 Operation-failure result

The operation-failure fixture used the same stable identities.

Both work units 0 and 1 had resident input before work unit 1 injected the
operation failure.

After failure observation:

- dispatch closed;
- work units 2 and 3 never started;
- work unit 1 never became completed;
- already-running work unit 0 was allowed to finish normally;
- both resident materializations were eventually released;
- the request remained incomplete/failed;
- final local residency was zero.

### 17.7 Cancellation result

R0.4b-4 admitted exactly two work units and deterministically held both after
successful materialization.

The coordinator observed cancellation while both were known active and
resident.

The measured rule was:

```text
observe cancellation
    ->
close dispatch
    ->
do not start later work
    ->
allow already-running work to reach ordinary completion
    ->
release all work-unit-local residency
    ->
return cancelled/incomplete request
```

Both already-running units completed normally.

The two later units never started.

Cancellation remained orchestration state.

No cancellation token was passed into RasterView, materialization primitives
or the neighbourhood kernel.

### 17.8 Empty-request result

R0.4b-5 established:

```text
valid empty request
    ->
valid empty decomposition
    ->
zero batches
    ->
zero workers
    ->
zero materializations
    ->
zero operations
    ->
zero resident bytes
    ->
successful request completion
```

No synthetic empty work unit was created.

### 17.9 Compiler evidence

At the final R0.4b experiment HEAD before documentation closure:

```text
DMD: 9 modules passed unittests
LDC: 9 modules passed unittests
```

This is current-family verification.

It is not a compiler-floor audit.

## 18. R0.4b research questions answered

### 18.1 Richer work-unit abstraction

The tested bounded-parallel strategy did **not** require a richer public
semantic work-unit type.

Concurrency did require stable research-local work identity for deterministic
failure injection, synchronization and completed-set accounting.

That evidence does not justify a public WorkUnit or Task type.

### 18.2 Ownership and retention

Independent work-unit-local retention was sufficient.

The experiment did not require:

- shared materialization ownership;
- explicit cross-worker reference counting;
- cache-consumer counts;
- cache eviction lifetime.

Those remain later concerns if a concrete strategy needs them.

### 18.3 Active-work and resident-memory bounds

An explicit `maxActiveWorkUnits` plus current/peak active-work accounting was
sufficient to prove the tested concurrency bound.

Current/peak aggregate resident-raster accounting was sufficient to measure the
tested memory lifetime.

However:

```text
bounded work-unit count
!=
general resident-byte budget
```

for arbitrary heterogeneous workloads.

R0.4b therefore does not close the future memory-admission question.

### 18.4 Need for a general scheduler

A general scheduler abstraction was not required.

A coordinator plus bounded disposable workers was sufficient for this
operation class and evidence goal.

The concrete batch-thread implementation is research machinery, not a selected
production architecture.

### 18.5 Stable work identity

Stable identity was useful and necessary for deterministic evidence.

It separated:

```text
decomposition member identity
from
execution/completion ordinal
```

without making identity part of the production raster API.

### 18.6 Failure rule for running siblings

The tested baseline is:

```text
failure observed
    ->
close dispatch
    ->
do not start later work
    ->
do not forcibly interrupt already-running siblings
```

An already-running sibling may complete and remain valid completed research
state even though the request fails.

No rollback is implied.

### 18.7 Cancellation rule for running work

The tested baseline is analogous:

```text
cancellation observed
    ->
close dispatch
    ->
suppress not-yet-started work
    ->
allow already-running work to complete
    ->
request remains cancelled
```

No RasterView or kernel cancellation mechanism was required.

### 18.8 Partial completion representation

A completed prefix is not a valid general parallel invariant.

The evidence supports:

```text
completed work-unit set
+
completed output coverage
```

as sufficient research representation for the tested partial completion
semantics.

This is not a public partial-result API.

### 18.9 Reassembly and completion order

For the selected exact local operation, output reassembly remained correct
under forced out-of-order completion.

The destination was derived from logical output regions rather than completion
position.

### 18.10 Concepts surviving both execution strategies

Across R0.4a synchronous and R0.4b bounded-parallel execution, the evidence now
supports these scheduler-neutral distinctions:

```text
output request != scheduler task
decomposition != scheduler policy
spatial dependency != execution order
work-unit completion != request completion
logical coordinates != resident coordinates
```

It also supports:

- explicit work-unit-local resource lifetime;
- request termination distinct from completed work;
- completed-set/coverage semantics under parallel termination;
- orchestration-level cancellation observation;
- final release of work-unit-local resident raster state.

## 19. R0.4b success gate — PASS

All twenty R0.4b contract gates passed:

1. **PASS** — synchronous and bounded-parallel successful output are exactly
   equivalent for the selected operation;
2. **PASS** — parallel bounds 2 and 3 were exercised;
3. **PASS** — actual concurrent overlap was proven without timing assumptions;
4. **PASS** — active work never exceeded the configured bound;
5. **PASS** — deterministic out-of-order completion did not change output;
6. **PASS** — aggregate resident-raster accounting is explicit;
7. **PASS** — final local residency is zero on success;
8. **PASS** — final local residency is zero after materialization failure;
9. **PASS** — final local residency is zero after operation failure;
10. **PASS** — final local residency is zero after cancellation;
11. **PASS** — failure suppressed not-yet-started work after observation;
12. **PASS** — cancellation suppressed not-yet-started work after observation;
13. **PASS** — already-running sibling behaviour is explicit and verified;
14. **PASS** — completed work remains distinguishable from request completion;
15. **PASS** — empty output remains successful zero-work execution;
16. **PASS** — non-zero logical coordinates remain distinct from resident
    coordinates;
17. **PASS** — historical R0.3 evidence remained unchanged;
18. **PASS** — historical R0.4a evidence remained unchanged;
19. **PASS** — production `source/raster/` remained unchanged;
20. **PASS** — no scheduling/cache/provider/image policy was promoted and DMD
    and LDC produced the same deterministic correctness result.

The experiment README retains the more granular twenty-one-item gate; the
contract's final two implementation-boundary/compiler checks are summarized
together here.

## 20. R0.4b final conclusion

R0.4b is **complete**.

For the selected exact independent region-local raster operation, the
scheduler-independent semantic contract established by R0.4a survived bounded
parallel execution.

The experiment established that:

1. bounded parallelism can preserve the synchronous semantic result;
2. completion order need not be semantic output order;
3. concurrent work-unit-local resident lifetimes can remain explicit and
   bounded by admitted active work;
4. failure and cancellation can close dispatch without forcibly interrupting
   already-running work;
5. completed work remains distinct from successful request completion;
6. parallel partial completion requires completed-set/coverage semantics rather
   than a completed-prefix assumption;
7. zero-work requests remain successful without synthetic tasks.

### 20.1 Promotion decision

**Do not promote the R0.4b research machinery into the production raster API.**

R0.4b did not require a public:

- scheduler;
- WorkUnit/Task type;
- cancellation token;
- execution graph;
- worker pool;
- cache;
- provider abstraction.

The batch-local threads, barriers, instrumentation structs, failure fixtures
and cancellation fixtures remain disposable research evidence.

The stable semantics may inform a later internal or public execution
abstraction only after additional R0.4 evidence and a concrete consumer justify
promotion.

### 20.2 Next execution-research boundary

R0.4b answered the bounded-parallel semantic question.

Later R0.4 work may now investigate scheduling policy, including topics such as:

- priority;
- fairness;
- interactive versus throughput work;
- starvation avoidance;
- more general worker-pool strategies.

Those questions must preserve the R0.4a/R0.4b semantic reference rather than
retroactively embedding scheduling policy into raster geometry, RasterView or
operation semantics.

## 21. R0.4c scheduling policy contract

R0.4c researches dispatch/admission policy above the execution semantics already
established by R0.4a and R0.4b.

Tracking issue:

```text
#16 research: define R0.4c scheduling policy semantics
```

R0.4c does not redefine execution correctness.

Its central separation is:

```text
what work is semantically required
!=
which ready work is admitted next
```

The first R0.4c question is:

> What is the smallest deterministic scheduling-policy model that can choose
> among multiple ready raster work units while preserving R0.4a/R0.4b
> semantics and making priority, fairness, interactive responsiveness and
> starvation behaviour explicit and measurable?

### 21.1 Inherited semantic baseline

R0.4c inherits the following R0.4a/R0.4b distinctions unchanged:

```text
output request != scheduler task
decomposition != scheduler policy
spatial dependency != execution order
work-unit completion != request completion
logical coordinates != resident coordinates
```

It also inherits:

- work-unit-local resident ownership/lifetime;
- bounded active work;
- completed-set/coverage semantics under parallel termination;
- failure/cancellation closing dispatch;
- already-running work not being forcibly interrupted;
- empty-request zero-work success;
- final release of work-unit-local resident state.

Scheduling policy must not weaken or reinterpret any of those semantics.

### 21.2 Policy scope

R0.4c policy may influence:

- which already-ready work unit is selected next;
- stable ordering among equivalent ready work;
- class/priority preference;
- fairness between ready classes;
- starvation prevention.

R0.4c policy must not change:

- logical output regions;
- dependency expansion;
- halo/context semantics;
- operation result;
- stable work identity;
- request-completion definition;
- failure/cancellation termination;
- ownership/lifetime rules.

### 21.3 Ready-work-only model

The first R0.4c experiment operates only on work that is already semantically
ready.

It does not need to model:

- dependency graphs becoming ready dynamically;
- pipeline-stage readiness;
- asynchronous I/O readiness;
- provider/decode readiness;
- prefetch readiness.

Those remain later R0.4 questions.

The initial scheduling-policy oracle may therefore receive a deterministic
research-local ready set directly.

### 21.4 Research-local policy metadata

The first experiment may use research-local metadata such as:

```text
stableWorkUnitId
readyOrdinal
policyClass
priority
```

These fields are evidence machinery.

They are not proposed raster API fields.

In particular, priority/class information must not be added to:

- Region2D;
- RasterView;
- WritableRasterView;
- dependency structures;
- raster operation signatures.

### 21.5 Stable identity and stable readiness order

Stable work identity remains distinct from ready-order position.

The experiment must distinguish:

```text
stableWorkUnitId
readyOrdinal
dispatchOrdinal
completionOrdinal
```

A policy may choose a different dispatch order without changing work identity
or semantic output placement.

For equal policy metadata, a deterministic policy should preserve a documented
stable tie-break.

The initial tie-break should use ready order rather than pointer identity,
thread identity or hash-table iteration order.

### 21.6 Candidate P0 — FIFO

P0 is the policy baseline.

Definition:

> Among ready work, admit the lowest ready ordinal first.

The experiment must verify:

- stable ordering;
- deterministic equal-class behaviour;
- no hidden priority effect.

P0 is a reference policy, not automatically a production recommendation.

### 21.7 Candidate P1 — strict priority

P1 always prefers the highest-priority ready work.

For equal priority, the first experiment should preserve FIFO-ready order.

P1 exists to answer two separate questions:

1. how strongly can policy prefer higher-priority/interactive work?
2. what starvation behaviour follows from strict preference?

The experiment must not assume that strict priority is acceptable merely
because it is simple.

### 21.8 Interactive and throughput classes

The first experiment should model at least two research-local policy classes:

```text
interactive
throughput
```

The class names are descriptive test metadata.

They do not imply a production enum.

Interactive work should be able to receive preferential admission.

The experiment must also determine whether continuously ready throughput work
can still make progress under sustained interactive arrivals.

### 21.9 Starvation workload

At least one deterministic adversarial workload must keep higher-priority work
continuously ready while one or more lower-priority work units remain ready.

Under strict priority, the experiment should make starvation directly
observable.

The evidence should distinguish:

```text
priority preference
from
bounded waiting
from
unbounded starvation
```

No wall-clock time is needed.

### 21.10 Fairness metric

The first fairness metric should be based on deterministic dispatch
opportunities rather than elapsed time.

Suitable measurements include:

```text
number of dispatch opportunities bypassed
service count per class
maximum consecutive admissions from one class
stable order within one class
```

The experiment must not claim CPU-time fairness from work-unit counts.

Work units may have heterogeneous future costs.

Therefore:

```text
dispatch fairness
!=
CPU-time fairness
```

unless later evidence explicitly models execution cost.

### 21.11 Candidate P2 — starvation-resistant preference

R0.4c must compare one deliberately small starvation-resistant policy with P0
and P1.

Candidate mechanisms include:

- bounded priority burst/quota;
- weighted round-robin between ready classes;
- aging.

The first implementation should select the simplest mechanism that can answer
the research question deterministically.

Selection for experiment use is not a production-policy decision.

### 21.12 Initial P2 preference

For the first experiment, a bounded priority burst is the preferred candidate
because it can be described and verified with minimal state.

One possible research-local form is:

```text
allow at most N consecutive interactive admissions
while throughput work remains continuously ready
then admit one throughput work unit
```

The exact N remains experiment configuration.

The important property is that the maximum bypass count is explicit and
testable.

If this model proves insufficient, the experiment may compare another
candidate without promoting the first one.

### 21.13 Fairness state

R0.4c should determine whether the starvation-resistant policy needs:

- per-work-unit state;
- per-class state;
- both.

The bounded-burst candidate is expected to need only:

- stable work metadata;
- small per-policy/per-class counters.

That hypothesis must be tested rather than assumed.

### 21.14 Deterministic policy oracle

The first policy evidence should prefer a deterministic oracle/simulation over
real thread timing.

A suitable model is:

```text
ready set
    ->
policy select
    ->
record dispatch
    ->
deterministic synthetic arrival/update
    ->
repeat
```

This allows starvation/fairness properties to be tested exactly.

No `sleep`, timeout or OS scheduler behaviour may be used as evidence.

### 21.15 Non-preemption

R0.4c initially researches admission order only.

Once work is admitted/running, the R0.4b non-preemption baseline remains:

> Running work is not forcibly interrupted by scheduling policy.

R0.4c therefore does not research:

- preemptive worker suspension;
- time slicing;
- OS thread priority;
- kernel interruption.

### 21.16 Active-work bound

Policy selection must respect the execution-side active-work bound:

```text
currentActiveWorkUnits <= maxActiveWorkUnits
```

Policy does not create permission to exceed that bound.

The first deterministic policy oracle may model one admission opportunity at a
time.

A later integration probe must demonstrate that policy-selected work can feed a
bounded executor without changing the bound.

### 21.17 Resident-memory boundary

R0.4c preserves the R0.4b distinction:

```text
bounded active-work count
!=
general resident-byte budget
```

Scheduling preference alone is not a memory-budget controller.

The first policy experiment should not silently turn priority/fairness metadata
into memory-admission policy.

If later evidence requires a byte-budget admission controller, that must be
introduced as a separate research concern.

### 21.18 Failure and cancellation

R0.4b request-termination semantics remain authoritative.

Once failure or cancellation is observed:

```text
dispatch closes
```

No policy may select/admit later ready work after that point.

The experiment must verify that this rule holds for:

- FIFO;
- strict priority;
- starvation-resistant policy.

Priority must never override request termination.

### 21.19 Completion and output semantics

Policy may change dispatch/completion order.

It must not change:

- logical output placement;
- exact result for the selected deterministic operation;
- request completion rules;
- completed-set/coverage meaning.

At least one integration probe should schedule an exact R0.4b-compatible raster
operation using two or more distinct policy orders and verify byte-identical
output.

### 21.20 Policy experiment phases

R0.4c should proceed in narrow evidence slices.

#### R0.4c-0 — policy vocabulary and reuse probe

Prove that the experiment can reuse R0.4a/R0.4b research evidence without
modifying historical sources.

No policy implementation beyond minimal metadata.

#### R0.4c-1 — FIFO baseline

Prove deterministic stable ready-order dispatch.

#### R0.4c-2 — strict priority

Prove deterministic higher-priority preference and stable tie-breaking.

#### R0.4c-3 — starvation evidence

Use sustained higher-priority arrivals to demonstrate deterministic starvation
or unbounded bypass under strict priority.

#### R0.4c-4 — starvation-resistant candidate

Implement one minimal bounded-wait alternative and prove an explicit bypass
bound while retaining interactive preference.

#### R0.4c-5 — termination gate

Prove that failure/cancellation closes dispatch independently of policy.

#### R0.4c-6 — raster integration

Feed policy-selected work into an exact R0.4b-compatible execution fixture and
prove that policy order does not change semantic output or active-work bounds.

### 21.21 Initial result matrix

The final experiment should report at least:

| Case | Policy | Required evidence |
| --- | --- | --- |
| equal-class ready work | FIFO | stable ready order |
| mixed priority | strict priority | high priority preferred |
| sustained high-priority arrivals | strict priority | starvation/bypass observable |
| sustained interactive arrivals | starvation-resistant | throughput progress bounded |
| equal policy metadata | all candidates | deterministic tie-break |
| termination after ready work exists | all candidates | no later dispatch |
| raster integration | at least two policy orders | byte-identical output |
| bounded integration | selected policy | active bound preserved |

### 21.22 Initial hypotheses

**H1 — policy remains orthogonal to raster semantics**

Scheduling policy can operate on research-local ready-work metadata without
changing Region2D, RasterView, dependency or operation APIs.

**H2 — FIFO is a useful deterministic baseline**

Stable ready-order selection provides a policy reference without priority
effects.

**H3 — strict priority exposes starvation**

Under sustained higher-priority arrivals, continuously ready lower-priority
work can be bypassed without a finite policy bound.

**H4 — bounded preference can preserve progress**

A small starvation-resistant policy can prefer interactive work while providing
a deterministic upper bound on throughput bypass opportunities.

**H5 — fairness can initially be measured without time**

Dispatch-opportunity metrics are sufficient for first-order scheduler-policy
evidence.

**H6 — request termination dominates policy**

Failure/cancellation closes dispatch regardless of policy preference.

**H7 — policy order does not change semantic raster output**

For the selected exact independent raster operation, different legal dispatch
orders remain byte-identical.

**H8 — no production scheduler API is yet required**

The required evidence can be obtained with disposable research policy types and
oracles.

### 21.23 Questions R0.4c must answer

1. What is the smallest policy input beyond stable work identity?
2. Is a two-class interactive/throughput model sufficient for first evidence?
3. Is FIFO stability useful as a scheduler-neutral baseline?
4. How severe is deterministic starvation under strict priority?
5. What is the simplest starvation-resistant policy that preserves preference?
6. How should fairness be measured without wall-clock timing?
7. Does fairness require per-work-unit state, per-class state, or both?
8. Can policy remain independent of raster geometry/dependency types?
9. Can request termination close admission independently of policy?
10. Does policy integration preserve exact R0.4b semantic output?
11. Does any scheduler-policy abstraction deserve promotion?

### 21.24 Explicit non-goals

R0.4c does not select or implement:

```text
work stealing
pipeline parallelism
decode/materialize/compute staging
async I/O
dynamic dependency readiness
prefetch
cache replacement
provider/source policy
preemptive execution
OS thread priority
CPU affinity
GPU scheduling
imagery-specific scheduling
```

It also does not promote:

```text
public Scheduler
public Priority
public WorkClass
public FairnessPolicy
public Task
public WorkUnit
```

### 21.25 Success gate

R0.4c evidence is sufficient only if all of the following hold:

1. FIFO ready-order behaviour is deterministic;
2. strict priority deterministically prefers higher-priority ready work;
3. strict-priority starvation/bypass is demonstrated under adversarial sustained load;
4. one starvation-resistant policy provides an explicit deterministic progress bound;
5. interactive work retains measurable preference under that policy;
6. throughput work still progresses under sustained interactive arrivals;
7. equal-policy metadata has a deterministic stable tie-break;
8. fairness/starvation evidence uses dispatch opportunities rather than wall-clock assumptions;
9. request termination suppresses later dispatch for every tested policy;
10. policy metadata remains research-local and outside raster geometry/view APIs;
11. bounded execution still respects `maxActiveWorkUnits`;
12. policy order does not change exact raster output in the integration probe;
13. historical R0.3/R0.4a/R0.4b evidence remains unchanged;
14. production `source/raster/` remains unchanged;
15. no pipeline/work-stealing/prefetch/provider/image policy is promoted;
16. DMD and LDC produce the same deterministic correctness results.

### 21.26 Promotion rule after R0.4c

Passing R0.4c would show that scheduling policy can vary while the same
execution semantics remain stable.

That is not automatic authorization for a public scheduler-policy API.

Any production promotion must still require:

- a concrete raster consumer;
- evidence that the abstraction is reusable beyond the experiment;
- stable semantics across more than one policy;
- compatibility with later worker-pool/pipeline/source research;
- clear ownership/lifetime boundaries;
- compiler-floor compatibility;
- acceptable public-surface cost.

If those conditions are not met, policy machinery remains internal or
research-local.

## 22. R0.4c measured evidence

R0.4c was implemented as deterministic research policy machinery under:

```text
experiments/r0_4c_scheduling_policy/
```

Evidence commits:

```text
189cf56 research: define R0.4c scheduling policy contract
d81ea80 research: prove R0.4c reuse of execution evidence
f490bb2 research: prove R0.4c FIFO scheduling baseline
083e9de research: prove R0.4c strict priority scheduling
bfdcbef research: prove R0.4c strict priority starvation
fe1dd02 research: prove R0.4c bounded interactive preference
8f2d3e2 research: prove R0.4c termination admission gate
dbed0dd research: prove R0.4c raster policy integration
```

Historical R0.3, R0.4a and R0.4b experiment sources remained unchanged.

Production `source/raster/` remained unchanged.

### 22.1 Reuse result

R0.4c-0 compiled and executed the immutable R0.4a synchronous and R0.4b
bounded-parallel references against the same legal decomposition.

The result was exact output equality and final local resident bytes of zero.

### 22.2 FIFO result

P0 FIFO established:

```text
lowest readyOrdinal first
```

`priority` and `policyClass` do not influence FIFO selection.

Equal policy metadata therefore has a stable deterministic ready-order
tie-break.

### 22.3 Strict-priority result

P1 established:

```text
highest numeric priority first
then lowest readyOrdinal
```

No fairness, quota or aging state is present in P1.

### 22.4 Strict-priority starvation result

One lower-priority throughput item remained continuously ready while a fresh
higher-priority interactive item became ready before every dispatch
opportunity.

Across horizons:

```text
1, 2, 8, 32, 128
```

the measured result was:

```text
bypassedOpportunities == dispatchOpportunities
lowerPriorityDispatched == false
```

Therefore strict priority supplies no finite bypass bound of its own.

This is deterministic dispatch-opportunity evidence, not a wall-clock claim.

### 22.5 Starvation-resistant bounded-burst result

P2 introduced:

```text
maxInteractiveBurst
consecutiveInteractiveAdmissions
```

while throughput remained continuously ready.

For tested burst sizes:

```text
1, 2, 3, 8
```

the measured bound was:

```text
maxObservedThroughputBypass == maxInteractiveBurst
```

and throughput received repeated service under sustained interactive arrivals.

Interactive preference remained explicit.

Within the chosen class, selection remained strict-priority plus ready-order
tie-breaking.

This establishes dispatch fairness only:

```text
dispatch fairness != CPU-time fairness
```

### 22.6 Termination-gate result

R0.4c-5 established a policy-independent gate:

```text
request termination observed
    ->
dispatch closed
    ->
no policy evaluation
    ->
no later admission
```

The rule was verified for FIFO, strict priority and bounded burst.

Closed dispatch also leaves bounded-burst fairness state unchanged.

Termination dominates policy validation.

### 22.7 Raster-integration result

The same six legal R0.4b decomposition members were scheduled in three
different orders:

```text
FIFO             0, 1, 2, 3, 4, 5
strict priority  3, 5, 1, 4, 2, 0
bounded burst    3, 5, 4, 1, 2, 0
```

Every order was passed to the immutable R0.4b bounded executor with:

```text
maxActiveWorkUnits = 2
```

For every policy:

```text
output == R0.4a synchronous output
completedCoverage == R0.4a completedCoverage
peakActiveWorkUnits <= maxActiveWorkUnits
currentResidentRasterBytes == 0
```

Therefore policy order did not become semantic raster output order.

### 22.8 Compiler evidence

At the final R0.4c experiment HEAD before documentation closure:

```text
DMD: 11 modules passed unittests
LDC: 11 modules passed unittests
```

This is current-family verification.

It is not a compiler-floor audit.

## 23. R0.4c research questions answered

### 23.1 Smallest useful policy input

The tested research vocabulary is:

```text
stableWorkUnitId
readyOrdinal
policyClass
priority
```

Policies consume only the subset they need.

FIFO needs stable ready order. Strict priority adds numeric priority.
Bounded-burst preference additionally uses policy class and small class-level
state.

### 23.2 Two-class model

Interactive and throughput classes were sufficient for the first starvation
and bounded-progress evidence.

This is not evidence that a future production scheduler needs exactly two
classes.

### 23.3 FIFO baseline

FIFO proved useful as a deterministic policy baseline with no hidden priority
effect.

### 23.4 Strict-priority starvation

Strict priority had no finite bypass bound under sustained higher-priority
arrivals.

### 23.5 Starvation-resistant candidate

A bounded interactive burst was sufficient for first evidence.

It preserved interactive preference and bounded throughput bypass using only
small policy/class-level state.

It is not selected as production policy.

### 23.6 Fairness metric

Dispatch opportunities and service counts were sufficient for first-order
policy evidence without wall-clock timing.

No CPU-time fairness claim was made.

### 23.7 Required fairness state

The bounded-burst candidate did not require per-work-unit aging.

It used only:

```text
maxInteractiveBurst
consecutiveInteractiveAdmissions
```

### 23.8 Geometry independence

Policy remained independent of Region2D, RasterView, dependency structures and
operation signatures.

### 23.9 Termination independence

Failure/cancellation closed admission before policy evaluation for every tested
policy.

### 23.10 Semantic-output preservation

Three distinct legal policy orders produced the exact R0.4a result through the
immutable R0.4b bounded executor.

### 23.11 Promotion

No scheduler-policy abstraction deserves public promotion yet.

The evidence supports internal semantic boundaries, not a stable public
Scheduler/Priority/WorkClass/FairnessPolicy API.

## 24. R0.4c success gate — PASS

All sixteen contract gates passed:

1. **PASS** — FIFO ready-order behaviour is deterministic;
2. **PASS** — strict priority prefers higher-priority ready work deterministically;
3. **PASS** — strict-priority starvation/bypass is demonstrated under sustained load;
4. **PASS** — one starvation-resistant policy provides an explicit deterministic progress bound;
5. **PASS** — interactive work retains measurable preference;
6. **PASS** — throughput work progresses under sustained interactive arrivals;
7. **PASS** — equal policy metadata has a stable deterministic ready-order tie-break;
8. **PASS** — fairness/starvation evidence uses dispatch opportunities rather than wall-clock assumptions;
9. **PASS** — request termination suppresses later dispatch for every tested policy;
10. **PASS** — policy metadata remains research-local and outside raster geometry/view APIs;
11. **PASS** — bounded execution respects `maxActiveWorkUnits`;
12. **PASS** — policy order does not change exact raster output;
13. **PASS** — historical R0.3/R0.4a/R0.4b evidence remained unchanged;
14. **PASS** — production `source/raster/` remained unchanged;
15. **PASS** — no pipeline/work-stealing/prefetch/provider/image policy was promoted;
16. **PASS** — DMD and LDC produced the same deterministic correctness result.

## 25. R0.4c final conclusion

R0.4c is **complete**.

The experiment establishes that ready-work scheduling policy can vary without
changing the execution semantics established by R0.4a/R0.4b for the selected
exact independent raster operation.

The evidence now supports:

```text
semantic work != policy metadata
ready order != priority order
dispatch preference != fairness guarantee
dispatch fairness != CPU-time fairness
request termination > policy preference
policy order != semantic raster output
```

### 25.1 Promotion decision

**Do not promote the R0.4c scheduling-policy machinery into the production raster API.**

Keep the following as research-local evidence:

- ReadyWork policy metadata;
- FIFO oracle;
- strict-priority oracle;
- bounded interactive-burst state/policy;
- termination-gate types;
- policy integration helpers.

R0.4c did not require a public Scheduler, Priority, WorkClass, FairnessPolicy,
Task or WorkUnit API.

### 25.2 Next execution-research boundary

R0.4d may now investigate pipeline parallelism and backpressure across stages
such as decode/materialize/compute.

That later research must preserve the R0.4a/R0.4b/R0.4c reference semantics
rather than embedding stage policy into raster geometry, RasterView or
operation correctness.

## 26. R0.4d contract — bounded pipeline backpressure

Tracking issue: #18

### 26.1 Central question

R0.4d asks:

> What is the smallest bounded staged raster-execution model that allows
> different raster work units to occupy different execution stages
> concurrently while preserving the R0.4a/R0.4b/R0.4c semantic reference and
> making inter-stage backpressure, stage ownership and termination cleanup
> explicit and testable?

The central separation is:

```text
semantic work
!=
pipeline stage
!=
stage admission / backpressure
```

### 26.2 Raster-d scope boundary

R0.4d researches **bounded staged raster execution**.

It does not research a general-purpose:

```text
pipeline framework
DAG executor
workflow engine
async task framework
```

A stage belongs in R0.4d only when it exists because of a generic raster
execution requirement.

Use this boundary test:

```text
Would the abstraction still make sense if the raster represented
elevation, temperature or another scientific grid instead of an image?

YES  -> candidate raster-d mechanism
NO   -> higher-level consumer / adapter concern
```

R0.4d may know about:

```text
raster work units
regions
dependency / halo
resident raster resources
work-unit lifecycle
bounded stage slots
handoff / backpressure
residency accounting
termination
```

R0.4d must not know about:

```text
JPEG / TIFF codec semantics
GDALDataset
COG / HTTP / WMS / WMTS policy
RGB / Lab / ICC semantics
alpha interpretation
radiometry
sensor or acquisition metadata
CRS / geotransform / GSD
imagery mosaicking policy
image-specific enhancement semantics
OSM or application workflow semantics
```

Therefore:

```text
generic raster execution mechanism
!=
image / source / application processing policy
```

A generic Graph/Node/Edge/Workflow abstraction must not be introduced merely
because staged execution needs ordering or handoff.

If a reusable graph executor becomes necessary, it requires separate evidence
that a linear bounded raster pipeline is insufficient and that the graph domain
is independently coherent.

### 26.3 Initial staged lifecycle

R0.4d starts with already-known semantic raster work.

The initial per-work-unit lifecycle is:

```text
not admitted
    ->
materializing
    ->
ready for compute
    ->
computing
    ->
completed / released
```

The first pipeline does not add real codec, decoder, file or network I/O.

Materialization continues to reuse deterministic procedural source mechanics
already established in R0.3/R0.4a/R0.4b.

### 26.4 Inherited semantics

R0.4d inherits unchanged:

- R0.4a exact synchronous semantic result;
- R0.4b bounded active-work semantics;
- R0.4b completed-set/coverage semantics;
- R0.4b non-preemption of already-running work after failure/cancellation;
- R0.4c separation of semantic work from scheduling-policy metadata;
- R0.4c rule that request termination dominates later admission;
- work-unit-local ownership and lifetime;
- final release of resident raster state;
- decomposition-independent exact output for the selected operation.

Historical R0.3/R0.4a/R0.4b/R0.4c experiment sources remain immutable.

Production `source/raster/` remains unchanged unless a later explicit
promotion decision is justified.

### 26.5 Initial bounded resources

The first model uses research-local bounds equivalent to:

```text
maxActiveWorkUnits
maxMaterializing
maxComputing
handoffCapacity
```

Definitions:

- **active work unit** — admitted to the pipeline and not yet terminal/released;
- **materializing** — currently executing the materialization stage;
- **ready for compute** — materialization completed and resident state retained
  while waiting for compute;
- **computing** — currently executing the operation stage;
- **handoff credit** — capacity reserved before materialization begins so that
  completed materialization always has bounded downstream holding capacity.

The initial handoff invariant is:

```text
materializing + readyForCompute <= handoffCapacity
```

Execution must also preserve:

```text
activeWorkUnits <= maxActiveWorkUnits
materializing <= maxMaterializing
computing <= maxComputing
```

These are work-count/resource-slot bounds.

They do not establish a general byte budget:

```text
bounded pipeline slots
!=
bounded resident bytes
```

### 26.6 Backpressure rule

Materialization may start only after obtaining handoff credit.

If no handoff credit is available:

```text
upstream materialization admission stops
```

even if additional semantic work is otherwise ready.

When compute begins for one ready-for-compute item, its handoff credit is
released and upstream materialization may resume.

This reservation-before-materialization rule prevents a fast upstream stage
from completing resident work that has nowhere bounded to wait downstream.

Backpressure correctness evidence must be deterministic.

Do not use:

```text
sleep
wall-clock delays
timeouts
OS scheduler timing
machine speed
```

as semantic evidence.

### 26.7 Stage ordering

For one work unit:

```text
materialization completion
    before
compute start
    before
successful work-unit completion
```

Different work units may occupy different stages concurrently.

Global stage completion order is not semantic output order.

### 26.8 Termination

Request failure/cancellation closes:

- admission of new work units;
- start of later stages for queued/not-running work.

Already-running materialization or compute is not forcibly interrupted.

If materialization finishes after termination, its resident result is released
instead of starting compute.

If a work unit is already ready for compute when termination is observed, it
must not start compute and its retained resident state must be released.

Already-running compute may finish and may contribute completed output/coverage
according to the R0.4b completed-set semantics.

Final cleanup must return all research-local active/resident counters to zero.

### 26.9 Initial stage-selection policy

Use deterministic FIFO/stable work identity within each stage for the first
R0.4d evidence.

R0.4d is not another scheduling-policy selection experiment.

R0.4c policy machinery remains research-local and is not promoted into the
pipeline contract.

### 26.10 Evidence slices

#### R0.4d-0 — vocabulary and reuse

- establish stage and backpressure vocabulary;
- compile/reuse immutable R0.4a/R0.4b/R0.4c references where useful;
- no threaded pipeline yet.

#### R0.4d-1 — deterministic pipeline state machine

Prove:

- legal per-work-unit transitions;
- active/materialize/compute/handoff bounds;
- explicit handoff-credit reservation/release;
- zero-work request behaviour.

No wall-clock timing.

#### R0.4d-2 — bounded pipeline success

Introduce bounded concurrent stage execution and prove:

- materialize/compute overlap across different work units;
- exact output equality with R0.4a;
- all configured count bounds;
- final release.

#### R0.4d-3 — deterministic backpressure

Hold downstream progress with explicit synchronization.

Prove:

- handoff capacity becomes fully reserved/occupied;
- additional materialization cannot start;
- upstream admission resumes after compute consumes/releases handoff credit.

#### R0.4d-4 — stage-order independence

Force deterministic out-of-order stage completion across work units and prove:

- exact output unchanged;
- coverage semantics unchanged;
- request completion independent of stage completion order.

#### R0.4d-5 — failure/cancellation cleanup

Inject termination at controlled stage boundaries.

Prove:

- no new work-unit admission after termination;
- queued ready-for-compute work does not start compute;
- already-running stages may finish;
- abandoned resident state is released;
- final counters/residency return to zero.

#### R0.4d-6 — raster integration

Run the exact neighbourhood operation through the bounded pipeline and compare
against both:

- R0.4a synchronous reference;
- R0.4b bounded-parallel reference.

### 26.11 Explicit non-goals

R0.4d does not select or implement:

```text
real asynchronous file/network I/O
codec/decode backends
provider/source policy
dynamic dependency discovery
work stealing
prefetch
cache replacement
general resident-byte budgeting
preemptive stage interruption
OS thread priority
CPU affinity
GPU execution
imagery-specific pipelines
public scheduler/pipeline APIs
general DAG/workflow execution
```

### 26.12 Initial hypotheses

**H1 — pipeline stages remain orthogonal to raster semantics**

Stage state can remain execution-local without changing Region2D, RasterView,
dependency or operation semantics.

**H2 — handoff credits are sufficient for first backpressure evidence**

Reservation before materialization can provide deterministic bounded upstream
admission without a general byte-budget controller.

**H3 — stage overlap preserves exact output**

Different work units can overlap materialization and compute while preserving
the exact semantic result.

**H4 — backpressure does not require wall-clock evidence**

Explicit synchronization and counters are sufficient.

**H5 — termination remains stronger than stage progress**

Failure/cancellation can prevent later stage starts while already-running stage
work retains R0.4b non-preemption semantics.

**H6 — slot bounds remain distinct from byte budgets**

Bounded stage counts do not imply a general resident-memory-byte guarantee.

**H7 — no public pipeline API is yet required**

Disposable research stage/queue/backpressure types are sufficient for the
evidence.

### 26.13 Questions R0.4d must answer

1. What is the minimum useful staged lifecycle for generic raster execution?
2. Is a linear materialize/compute pipeline sufficient for first evidence?
3. Is reservation-before-materialization the right handoff/backpressure model?
4. Which counters are semantic evidence and which are implementation detail?
5. Can stage overlap be proven deterministically without timing assumptions?
6. Can termination prevent later stage starts without preempting running work?
7. Can resident state always be released after success, failure and cancellation?
8. Does exact raster output remain independent of stage overlap/completion order?
9. Does the model stay inside raster-d rather than becoming a general workflow engine?
10. Does any pipeline/backpressure abstraction deserve promotion?

### 26.14 Success gate

R0.4d evidence is sufficient only if:

1. stage vocabulary is explicit and deterministic;
2. per-work-unit stage order is enforced;
3. at least two different work units demonstrably overlap different stages;
4. `activeWorkUnits <= maxActiveWorkUnits`;
5. `materializing <= maxMaterializing`;
6. `computing <= maxComputing`;
7. handoff credit use never exceeds `handoffCapacity`;
8. full handoff capacity deterministically blocks additional upstream materialization;
9. upstream progress resumes after handoff credit is released;
10. backpressure evidence uses no wall-clock/sleep assumption;
11. failure/cancellation closes new work-unit admission;
12. queued/not-running later stages do not start after termination;
13. all retained resident state is released on success/failure/cancellation;
14. pipeline execution remains byte-identical to the exact semantic reference;
15. historical evidence and production `source/raster/` remain unchanged and
    the raster-d scope gate is not crossed;
16. DMD and LDC produce the same deterministic correctness results.

### 26.15 Promotion rule

Passing R0.4d does not authorize a public:

```text
Pipeline
Stage
Queue
BackpressureController
Executor
Graph
Workflow
```

API.

Promotion requires a concrete raster consumer and evidence that the abstraction:

- remains generic across non-image raster domains;
- survives later source/I/O and worker-pool research;
- does not collapse into provider/image/application policy;
- has clear ownership/lifetime semantics;
- is worth the public-surface cost.

Until then, all R0.4d stage/queue/backpressure machinery remains disposable
research evidence.

## 27. R0.4d measured evidence

R0.4d evidence commits:

```text
e9f8665  vocabulary and historical-reference reuse
d76f921  deterministic pipeline state machine
68b1ccc  bounded real stage overlap
1319838  deterministic backpressure
c06ae73  stage-order independence
43196c7  termination cleanup
ff86c02  raster pipeline integration
```

### 27.1 Vocabulary and state-machine result

The tested success lifecycle is:

```text
notAdmitted
    ->
materializing
    ->
readyForCompute
    ->
computing
    ->
completed
    ->
released
```

Termination cleanup additionally permits:

```text
readyForCompute
    ->
released
```

without compute.

The exact accounting identities are:

```text
activeWorkUnits
==
materializing
+ readyForCompute
+ computing
+ completedPendingRelease
```

and:

```text
handoffCreditsInUse
==
materializing
+ readyForCompute
```

### 27.2 Cross-stage overlap result

With:

```text
maxActiveWorkUnits = 2
maxMaterializing  = 1
maxComputing      = 1
handoffCapacity   = 1
```

real raster execution reached the observed state:

```text
work A: computing
work B: materializing
```

while both stages were held by explicit barriers.

The assembled output and coverage were exact-equal to R0.4a.

### 27.3 Backpressure result

With handoff capacity two:

```text
readyForCompute      = 2
handoffCreditsInUse  = 2
```

an otherwise-admissible third materialization start failed specifically with:

```text
handoffCapacityReached
```

without mutation.

Starting compute for one ready item released one handoff credit.

The same third work unit then entered materialization successfully while compute
remained in flight.

### 27.4 Completion-order result

Two real compute stages were forced to complete in both orders:

```text
0 -> 1
1 -> 0
```

Both runs produced exact R0.4a output and coverage.

After only the first completion:

```text
requestCompleted == false
```

After complete required coverage and release:

```text
requestCompleted == true
```

### 27.5 Termination result

Failure while materialization was already running proved:

```text
failure observed
    ->
new admission closed
    ->
running materialization may finish
    ->
later compute start blocked
    ->
retained resident state released
```

Cancellation while compute was already running proved:

```text
cancellation observed
    ->
queued ready compute blocked
    ->
new admission closed
    ->
running compute may finish
    ->
partial completed coverage may publish
    ->
queued retained work released without compute
```

All tested termination paths ended with zero active/handoff/resident state.

### 27.6 Final raster-integration result

The canonical six-member legal decomposition was executed through:

```text
R0.4a synchronous
R0.4b bounded parallel
R0.4d bounded staged pipeline
```

The R0.4d runner observed five deterministic adjacent cross-stage overlaps:

```text
compute(i) || materialize(i + 1)
```

For R0.4d:

```text
peakActiveWorkUnits       = 2
peakMaterializing         = 1
peakComputing             = 1
peakHandoffCreditsInUse   = 1
```

and:

```text
output == R0.4a output
output == R0.4b output
completedCoverage == R0.4a completedCoverage
completedCoverage == R0.4b completedCoverage
currentResidentRasterBytes == 0
```

R0.4b also ended with zero resident raster bytes.

### 27.7 Compiler evidence

At the final R0.4d experiment HEAD before documentation closure:

```text
DMD: 17 modules passed unittests
LDC: 17 modules passed unittests
```

This is current-family verification.

It is not a compiler-floor audit.

## 28. R0.4d research questions answered

### 28.1 Minimum useful staged lifecycle

The tested lifecycle is:

```text
notAdmitted
materializing
readyForCompute
computing
completed
released
```

plus `readyForCompute -> released` for termination cleanup.

### 28.2 Linear pipeline sufficiency

A linear materialize/compute pipeline was sufficient for first generic raster
stage-overlap and backpressure evidence.

No DAG/general workflow model was required.

### 28.3 Handoff reservation model

Reservation before materialization was sufficient for deterministic upstream
backpressure.

Compute start releases the retained handoff credit.

### 28.4 Evidence counters

The useful first-order counters were:

```text
activeWorkUnits
materializing
readyForCompute
computing
completedPendingRelease
handoffCreditsInUse
```

plus peak values.

They remain research evidence, not public API.

### 28.5 Deterministic overlap

Explicit barriers were sufficient to prove cross-stage overlap without
wall-clock assumptions.

### 28.6 Termination without preemption

Request closure prevented later stage starts while already-running
materialization/compute remained non-preemptive.

### 28.7 Resident cleanup

All tested success/failure/cancellation paths returned retained resident state
to zero.

### 28.8 Output-order independence

Forced compute completion order did not alter exact output, coverage or final
request completion.

### 28.9 Raster-d boundary

The experiment remained generic raster execution research.

It did not introduce image, codec, CRS, provider, network, OSM or application
semantics.

It also did not require a general Graph/Workflow abstraction.

### 28.10 Promotion

No pipeline/backpressure type deserves production promotion yet.

## 29. R0.4d success gate — PASS

All sixteen contract gates passed:

1. **PASS** — stage vocabulary is explicit and deterministic;
2. **PASS** — per-work-unit stage order is enforced;
3. **PASS** — at least two different work units overlap different stages;
4. **PASS** — `activeWorkUnits <= maxActiveWorkUnits`;
5. **PASS** — `materializing <= maxMaterializing`;
6. **PASS** — `computing <= maxComputing`;
7. **PASS** — handoff usage never exceeds `handoffCapacity`;
8. **PASS** — full handoff capacity deterministically blocks upstream materialization;
9. **PASS** — upstream progress resumes after handoff-credit release;
10. **PASS** — backpressure correctness uses no wall-clock/sleep assumption;
11. **PASS** — failure/cancellation closes new work-unit admission;
12. **PASS** — queued/not-running later stages do not start after termination;
13. **PASS** — retained resident state is released on success/failure/cancellation;
14. **PASS** — pipeline execution is byte-identical to exact semantic references;
15. **PASS** — historical evidence and production `source/raster/` remain unchanged and the raster-d scope gate was not crossed;
16. **PASS** — DMD and LDC produced the same deterministic correctness result.

## 30. R0.4d final conclusion

R0.4d is **complete**.

The evidence establishes:

```text
semantic work
!=
pipeline stage
!=
stage admission / backpressure

bounded pipeline slots
!=
general resident-byte budget

stage completion order
!=
semantic raster output

request termination
>
later stage admission

running stage
!=
preemptible stage
```

A bounded staged raster execution model can overlap materialization and compute
while preserving the exact semantic result established by R0.4a/R0.4b.

Reservation-before-materialization handoff credits are sufficient for first
deterministic backpressure evidence.

Termination can close later stage starts without preempting already-running
work, while retained resident state is still released completely.

### 30.1 Promotion decision

**Do not promote the R0.4d pipeline/backpressure machinery into the production raster API.**

Keep these research-local:

- stage enum/vocabulary;
- stage limits and accounting;
- deterministic state machine;
- handoff-credit bookkeeping;
- termination gate;
- ready-without-compute cleanup transition;
- barrier-based proof workers;
- shared experiment raster fixture;
- integrated linear pipeline runner.

R0.4d did not justify a public Pipeline, Stage, Queue, BackpressureController,
Executor, Graph, Workflow or CancellationToken API.

### 30.2 Next execution-research boundary

R0.4e may investigate advanced execution questions only where independently
justified.

Possible later topics include:

```text
worker pools
work stealing
prefetch
deeper resource control
other advanced execution mechanisms
```

They must not be retroactively folded into R0.4d.

Real codec/decode/file/network source execution remains outside R0.4d and must
preserve the raster-d scope boundary.

Any later execution abstraction must preserve the R0.4a/R0.4b/R0.4c/R0.4d
semantic references rather than embedding execution policy into raster
geometry, views or operation correctness.

