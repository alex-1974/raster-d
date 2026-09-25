# R0.4b Bounded Parallel Execution Experiment

Status: R0.4b evidence complete
Date: 2026-09-25
Tracking issue: #14

Contract baseline:

```text
b9f43f5 research: define R0.4b bounded parallel execution contract
```

Evidence commits:

```text
5988188 research: define R0.4b parallel execution experiment
ff5da8e research: prove R0.4b reuse of prior execution evidence
b09d75b research: prove R0.4b bounded parallel success
aaceb24 research: prove R0.4b out-of-order completion
3bfa813 research: prove R0.4b parallel failure semantics
6106a32 research: classify R0.4b operation failure explicitly
4a06bc3 research: prove R0.4b parallel cancellation semantics
6c5bf93 research: prove R0.4b empty parallel request
```

Authoritative research document:

```text
docs/research/execution.md
```

Nothing in this experiment directory is a stable public API.

## 1. Purpose

R0.4b tests whether the scheduler-independent execution semantics established
by R0.4a survive bounded concurrent execution of independent raster work units.

R0.4a remains the semantic reference.

The experiment does not attempt to select a production scheduler.

Its question is narrower:

> What additional execution-side state is required because more than one work
> unit may be active at the same time?

The experiment must distinguish concurrency requirements from scheduling
policy.

## 2. Research boundary

R0.4b must not modify:

```text
source/raster/
experiments/r0_3_regions_streaming/
experiments/r0_4a_synchronous_execution/
```

Historical R0.3 and R0.4a evidence remains immutable.

The experiment does not select or implement production policy for:

- priority;
- fairness;
- work stealing;
- pipeline parallelism;
- decode/materialize/compute staging;
- prefetch;
- asynchronous I/O;
- dynamic dependency readiness;
- cache-block policy;
- shared-cache lifetime;
- provider/source policy;
- imagery-specific scheduling;
- GPU execution.

It does not promote:

- a public scheduler;
- a public WorkUnit;
- a public Task;
- a public cancellation token;
- a public execution graph.

If the first bounded-parallel experiment requires one of those concepts merely
to demonstrate independent concurrent work, the experiment is too broad.

## 3. Inherited invariants

R0.4b inherits these distinctions unchanged:

```text
output request != scheduler task
decomposition != scheduler policy
spatial dependency != execution ordering
work-unit completion != request completion
logical coordinates != resident coordinates
```

The central correctness rule remains:

```text
legal decomposition must not change the semantic result
```

For the selected exact local operation, execution strategy must not change the
result:

```text
synchronous sequential
==
bounded parallel
```

R0.4b must not weaken:

- RasterView ownership;
- WritableRasterView ownership;
- lease lifetime;
- region/dependency semantics;
- halo/context semantics;
- operation-specific failure guarantees.

## 4. Selected operation class

The initial experiment reuses the exact weighted 3 x 3 neighbourhood operation
already exercised by R0.3 and R0.4a.

The selected operation has:

- disjoint output regions;
- read-only input dependencies;
- independently materializable required input;
- exact deterministic output;
- no cross-work-unit mutable state.

This selection is intentionally narrow.

Passing this experiment does not establish arbitrary parallel execution for:

- floating-point reductions;
- incremental aggregates;
- stateful operations;
- multi-stage pipelines;
- operations with shared mutable state.

Those operation classes may require additional execution or combination
semantics.

## 5. Reference strategy

The R0.4a synchronous executor is the strategy oracle.

For a fixed request and legal decomposition:

```text
R0.4a synchronous result
==
R0.4b bounded-parallel result
```

Byte equality is required for the selected exact integer operation.

The R0.4b executor must not modify the R0.4a implementation to produce that
equality.

## 6. Research-local work identity

Parallel evidence requires stable work-unit identity.

The initial experiment should identify every decomposition member by a stable
research-local index:

```text
workUnitId
```

The identity belongs to the experiment.

It is not a proposed production task identifier.

Failure injection, deterministic synchronization and completion accounting
must refer to stable work identity rather than nondeterministic execution
ordinal.

For example:

```text
fail workUnitId 3
```

is suitable.

This is not suitable:

```text
fail whichever work unit happens to complete third
```

## 7. Work-state vocabulary

The experiment may observe these research-local states:

```text
not started
running
completed
failed
```

Cancellation is initially a request/coordinator termination state rather than
a separate terminal state that must be assigned to every individual work unit.

A work unit becomes running only after the coordinator admits it.

A work unit becomes completed only after successful operation execution reaches
the ordinary R0.4a completion boundary.

A failed work unit never becomes completed.

A work unit suppressed by failure or cancellation remains not started.

These states are experiment instrumentation only.

## 8. Explicit parallelism bound

The initial executor receives:

```text
maxActiveWorkUnits
```

The first success experiment must exercise at least:

```text
maxActiveWorkUnits = 2
maxActiveWorkUnits = 3
```

The decomposition must contain more work units than either bound.

At every observable point:

```text
currentActiveWorkUnits <= maxActiveWorkUnits
```

The experiment must also prove actual overlap:

```text
peakActiveWorkUnits > 1
```

for the parallel cases.

The implementation must not create one unbounded thread/task per decomposition
member and rely on incidental operating-system serialization.

## 9. Deterministic concurrency

No correctness claim may depend on wall-clock timing.

The tests must not use:

```text
sleep
arbitrary timeout delay
CPU-speed assumption
scheduler luck
```

to prove overlap or completion order.

Research-local deterministic synchronization is permitted.

Suitable concepts include:

- barriers;
- latches;
- condition-based gates;
- explicit coordinator/worker handshakes.

The exact primitive is implementation machinery, not a proposed production
execution API.

The synchronization fixture must make it possible to prove deterministically:

1. a known set of work units is running concurrently;
2. a chosen work unit cannot complete until another chosen event occurs;
3. completion order differs from decomposition order when required;
4. failure/cancellation is observed while a known bounded set is already
   running.

## 10. Initial dispatch rule

The coordinator may admit new work only while:

```text
request termination not observed
and
currentActiveWorkUnits < maxActiveWorkUnits
```

R0.4b needs only enough dispatch machinery to preserve the explicit bound and
observe lifecycle transitions.

It does not need:

- priority queues;
- fairness policy;
- work stealing;
- processor affinity;
- queue affinity;
- prefetch;
- dynamic readiness graphs.

A coordinator plus a small bounded worker mechanism is preferred until
evidence demonstrates that a richer scheduler abstraction is necessary.

## 11. Concurrent residency

Each running work unit independently retains its own work-unit-local resident
materialization.

The initial experiment deliberately excludes shared input materialization.

Research accounting must expose at least:

```text
currentResidentRasterBytes
peakResidentRasterBytes
```

where current resident bytes are the aggregate of all work-unit-local resident
raster materializations currently retained by active work.

Every return path must end with:

```text
currentResidentRasterBytes == 0
```

This applies to:

- success;
- materialization failure;
- operation failure;
- cancellation;
- empty request.

Parallel peak residency is allowed to exceed the residency of one synchronous
work unit.

The required property is that active work and corresponding local residency
remain explicitly bounded.

## 12. No shared-lifetime experiment yet

The first R0.4b experiment must not add shared materialization reuse merely
because several work units are active.

It does not require:

- reference-counted shared resident input;
- dependency-consumer counting;
- cache ownership;
- eviction;
- prefetch lifetime.

If independent work-unit-local residency is sufficient, those mechanisms remain
later research.

## 13. Completion order

The experiment distinguishes:

```text
decomposition order
start order
completion order
logical output placement
```

Completion order must not determine output placement.

The experiment must force at least one deterministic successful execution where
completion order differs from decomposition order.

The final result must remain byte-identical to the R0.4a synchronous result.

## 14. Result publication model

The initial experiment should isolate parallel work execution from concurrent
writes into one shared final output buffer.

Preferred first model:

```text
worker:
    execute one work unit
    return one completed work-unit result

coordinator:
    observe completed result
    reassemble it into request output/oracle state
```

This keeps output publication single-coordinator and allows the experiment to
focus on concurrent work-unit lifetime.

It does not establish that production raster execution must use temporary
per-work-unit output.

Later research may compare direct disjoint writes if a concrete need appears.

## 15. Completed-set semantics

R0.4a naturally produced a completed prefix because execution was sequential.

Parallel execution must not assume that property.

R0.4b tracks:

```text
completed work-unit set
completed output coverage
```

For example, after a failure the completed set may be:

```text
{0, 2, 4}
```

rather than a prefix.

Completed work remains distinguishable from request completion.

The completion coverage map remains research/test instrumentation.

It is not a public partial-result API.

## 16. Request completion

A non-empty request is complete if and only if:

1. every required work unit completed successfully;
2. no failure terminated the request;
3. cancellation did not terminate the request;
4. all work-unit-local resident raster state has been released.

Therefore:

```text
some completed work units
!=
completed request
```

The successful empty request remains a special zero-work case.

## 17. Failure injection

R0.4b separately exercises:

- materialization failure;
- operation failure.

Failure injection is deterministic and keyed by stable work-unit identity.

The failure fixture must arrange that, when failure is observed, a known set of
sibling work units is already running.

No new work may be admitted after the coordinator observes failure.

The failing work unit never becomes completed.

## 18. Already-running siblings after failure

The initial rule is:

> Failure closes dispatch, but does not forcibly interrupt work units that were
> already running when failure was observed.

Already-running siblings may reach their ordinary completion boundary.

Every already-running sibling must release its work-unit-local residency.

A successfully finishing sibling may become completed even though the overall
request is already destined to fail.

The experiment must therefore distinguish:

```text
failed request
completed work-unit set
failed work unit
not-started work units
```

R0.4b does not require rollback of completed sibling work.

## 19. Failure non-goals

The initial experiment does not need to define:

- simultaneous independent failures;
- first-error precedence;
- multi-error aggregation;
- rollback;
- atomic request publication;
- interruption of running workers.

Those questions remain deferred unless later evidence requires them.

## 20. Cancellation injection

Cancellation is deterministic and controlled by research orchestration.

The initial rule remains scheduler-neutral:

> Cancellation is observed by orchestration, not RasterView, materialization
> primitives or the neighbourhood kernel.

When cancellation is observed:

```text
stop admitting new work
```

Not-yet-started work remains not started.

Already-running work is not forcibly interrupted.

It may reach its ordinary completion boundary and must release local residency.

The request remains cancelled and incomplete.

No public cancellation-token API is introduced.

## 21. Active-work cancellation fixture

The experiment must include cancellation while a known set of at least two
work units is already running.

Deterministic synchronization must prove the active set without timing
assumptions.

The test verifies:

- peak active work is greater than one;
- no additional work starts after cancellation observation;
- already-running work follows the documented completion rule;
- completed-set/coverage accounting remains valid;
- requestCompleted is false;
- final resident raster bytes are zero.

## 22. Empty request

A valid empty request through the bounded-parallel entry path must:

```text
start zero work units
activate zero workers
materialize zero raster data
execute zero operations
finish with zero local residency
complete successfully
```

No synthetic empty work unit is created.

## 23. Principal fixture

The principal fixture should use:

- deterministic procedural `ubyte` input;
- non-zero logical origin;
- an interior output request with full one-pixel context;
- the exact weighted 3 x 3 neighbourhood operation;
- one deliberately irregular legal decomposition;
- more decomposition members than the largest tested parallel bound.

The fixture should be directly comparable with the R0.4a synchronous result.

A suitable starting geometry may reuse the R0.4a logical extent and output
request while increasing or reshaping decomposition membership as needed to
exercise bounded overlap.

## 24. Required instrumentation

The experiment should record at least:

```text
workUnitsRequired
workUnitsStarted
workUnitsCompleted
workUnitsFailed
currentActiveWorkUnits
peakActiveWorkUnits

materializationsStarted
materializationsCompleted

operationExecutionsStarted
operationExecutionsCompleted

currentResidentRasterBytes
peakResidentRasterBytes
releaseCount

completedWorkUnitSet
completedCoverage

requestCompleted
terminationReason
```

Additional research-only synchronization diagnostics may be recorded when
needed.

Instrumentation is not a proposed production telemetry API.

## 25. Deterministic completion-order fixture

At least one success test must force completion order different from
decomposition order.

A suitable pattern is:

```text
admit work units 0 and 1

hold work unit 0 at a research gate

allow work unit 1 to complete

release work unit 0
```

The observed completion order then begins:

```text
1, 0, ...
```

while logical output placement remains based on each work unit's region.

No sleep is permitted to enforce this order.

## 26. Deterministic failure fixture

A suitable first failure pattern is:

```text
maxActiveWorkUnits = 2

admit work unit A
admit failing work unit B

hold A at a deterministic gate
observe B failure
close dispatch
release A
wait for A to finish
```

This makes the post-failure sibling rule measurable:

- B fails and never completes;
- A was already running and may complete;
- later work never starts;
- request remains failed;
- final residency returns to zero.

Materialization failure and operation failure should each receive their own
fixture.

## 27. Deterministic cancellation fixture

A suitable first cancellation pattern is:

```text
maxActiveWorkUnits = 2

admit work unit A
admit work unit B

hold both at deterministic research gates
observe cancellation in coordinator
close dispatch
release A and B
wait for both to finish
```

Then verify:

- A and B were running when cancellation was observed;
- no third work unit started;
- A/B follow the documented already-running rule;
- request remains cancelled;
- final residency is zero.

## 28. Reuse of R0.3 and R0.4a evidence

The dependency direction is:

```text
R0.4b experiment
    ->
R0.4a synchronous reference / selected helpers
    ->
selected immutable R0.3 research modules
    ->
production raster-d API
```

R0.4b must not edit R0.4a or R0.3 merely for convenience.

### 28.1 R0.3 reuse

R0.4b may compile the same selected immutable R0.3 modules already consumed by
R0.4a:

```text
region_algebra.d
dependency.d
decomposition_oracle.d
procedural_source.d
neighbourhood_kernel.d
neighbourhood_task_execution.d
```

The existing R0.3 task execution remains an independent correctness oracle
where useful.

### 28.2 R0.4a reuse

R0.4b should compile the immutable R0.4a synchronous implementation as the
strategy oracle.

It may call the public-to-experiment function:

```text
executeSynchronousNeighbourhood()
```

if direct sibling-module compilation permits that without modifying R0.4a.

R0.4b must not use the R0.4a sequential orchestration as its parallel lifecycle
under test.

### 28.3 No copied algorithms

R0.4b must not copy:

- dependency expansion;
- decomposition validation;
- procedural materialization;
- weighted-neighbourhood arithmetic.

New code should be limited to parallel orchestration, deterministic
synchronization, accounting, result collection/reassembly and failure/
cancellation injection.

## 29. Initial implementation shape

The experiment should start small:

```text
experiments/r0_4b_bounded_parallel_execution/
    README.md
    dub.sdl
    reuse_probe.d
    bounded_parallel_execution.d
```

Additional modules are justified only when independent concerns become
difficult to audit in that shape.

The experiment must not grow into a reusable scheduler framework.

## 30. Evidence slices

R0.4b should be implemented in narrow commits.

### R0.4b-0 — reuse probe

Prove that the new experiment can compile the required immutable R0.3 and
R0.4a research sources together.

No parallel execution yet.

### R0.4b-1 — bounded success

Prove:

```text
R0.4a synchronous output
==
parallel bound 2 output
==
parallel bound 3 output
```

and:

```text
1 < peakActiveWorkUnits <= maxActiveWorkUnits
currentResidentRasterBytes == 0 at return
```

### R0.4b-2 — deterministic out-of-order completion

Force completion order different from decomposition order without sleep.

Prove exact output equality.

### R0.4b-3 — parallel failure

Separately prove deterministic:

- materialization failure;
- operation failure.

At failure observation, known sibling work is already running.

Prove dispatch closure, sibling rule and final cleanup.

### R0.4b-4 — parallel cancellation

Observe cancellation while known sibling work is active.

Prove dispatch closure, sibling rule, incomplete request and final cleanup.

### R0.4b-5 — empty request

Prove successful zero-work behaviour through the parallel entry path.

## 31. Initial hypotheses

### H1 — strategy equivalence

For the selected exact local operation:

```text
synchronous == bounded parallel
```

for at least two bounds greater than one.

### H2 — bounded active work

Parallel overlap occurs while:

```text
peakActiveWorkUnits <= maxActiveWorkUnits
```

always holds.

### H3 — bounded aggregate residency

Concurrent resident raster state remains explicit and finite.

Final work-unit-local residency is zero on every tested return path.

### H4 — completion-order independence

Forced out-of-order completion does not change semantic output.

### H5 — failure cleanup

Failure closes dispatch; the failed work unit remains incomplete; already
running siblings follow the documented completion rule; final residency is
zero.

### H6 — cancellation cleanup

Cancellation closes dispatch; not-started work remains suppressed; already
running work follows the documented completion rule; final residency is zero.

### H7 — no premature public abstraction

The evidence can be obtained without changing RasterView or introducing a
production scheduler/work-unit/cancellation API.

## 32. Required result matrix

The final experiment should report at least:

| Case | Bound | Expected request result | Required special evidence |
| --- | ---: | --- | --- |
| synchronous oracle | 1 | success | R0.4a reference |
| bounded success | 2 | success | overlap; exact equality |
| bounded success | 3 | success | overlap; exact equality |
| forced out-of-order completion | 2 | success | completion order differs |
| materialization failure with active sibling | 2 | failure | dispatch closes; cleanup |
| operation failure with active sibling | 2 | failure | dispatch closes; cleanup |
| cancellation with active siblings | 2 | cancelled | no later starts; cleanup |
| empty request | any valid bound | success | zero work |

Every case must end with zero work-unit-local resident raster bytes.

## 33. Success gate

R0.4b is complete only when all of these are demonstrated:

1. synchronous and bounded-parallel output are exactly equivalent for the
   selected operation;
2. at least bounds 2 and 3 are exercised;
3. real concurrent overlap is proven without timing assumptions;
4. active work never exceeds the configured bound;
5. deterministic out-of-order completion does not change output;
6. aggregate resident raster accounting is explicit;
7. final residency is zero on success;
8. final residency is zero after materialization failure;
9. final residency is zero after operation failure;
10. final residency is zero after cancellation;
11. failure suppresses not-yet-started work after observation;
12. cancellation suppresses not-yet-started work after observation;
13. already-running sibling behaviour is explicit and verified;
14. completed work remains distinct from request completion;
15. empty output remains successful zero-work execution;
16. logical coordinates remain distinct from resident coordinates;
17. historical R0.3 evidence remains unchanged;
18. historical R0.4a evidence remains unchanged;
19. production `source/raster/` remains unchanged;
20. no scheduling/cache/provider/image policy is promoted;
21. DMD and LDC produce the same deterministic correctness result.

## 34. Measured result matrix

The completed experiment produced the following evidence:

| Case | Bound | Request result | Completed work | Dispatch after termination | Final local residency |
| --- | ---: | --- | --- | --- | ---: |
| R0.4a synchronous oracle | 1 | success | all required work | n/a | 0 |
| bounded success | 2 | success | all 6 work units | normal | 0 |
| bounded success | 3 | success | all 6 work units | normal | 0 |
| forced out-of-order completion | 2 | success | both work units; completion order 1, 0 | normal | 0 |
| materialization failure | 2 | failure | already-running sibling completed; failing unit did not | closed; 2 later units never started | 0 |
| operation failure | 2 | failure | already-running sibling completed; failing unit did not | closed; 2 later units never started | 0 |
| cancellation with active work | 2 | cancelled | 2 already-running units completed | closed; 2 later units never started | 0 |
| empty request | 2 | success | zero work | no dispatch | 0 |

For the successful bounded executions:

```text
R0.4a synchronous output
==
R0.4b bound-2 output
==
R0.4b bound-3 output
```

byte-for-byte.

The bound-2 and bound-3 fixtures deterministically proved:

```text
peakActiveWorkUnits == configured bound
peakActiveWorkUnits > 1
```

without wall-clock timing.

The successful fixtures also proved that aggregate resident-raster lifetime was
concurrent: peak parallel resident raster bytes exceeded the synchronous
single-work-unit peak while final local residency still returned to zero.

The experiment records aggregate resident bytes explicitly but does not claim
that a work-count bound is a general-purpose byte-budget admission policy for
heterogeneous future workloads.

## 35. Deterministic completion evidence

R0.4b-2 forced:

```text
decomposition order:
    0, 1

completion/publication order:
    1, 0
```

using research-local barriers rather than `sleep` or scheduler timing.

The final output remained exactly equal to the R0.4a synchronous oracle.

This establishes for the selected operation that completion order is not
semantic output order.

Logical output placement remains a property of the work unit's region.

## 36. Failure evidence

R0.4b-3 used stable work-unit identity:

```text
work unit 0 -> already-running sibling
work unit 1 -> injected failure
work units 2 and 3 -> not yet started
```

Both materialization and operation failure were exercised separately.

In each case:

1. work unit 0 was already running when failure was observed;
2. work unit 1 never became completed;
3. the coordinator closed dispatch after observing failure;
4. work units 2 and 3 never started;
5. work unit 0 was allowed to reach its ordinary completion boundary;
6. completed sibling coverage remained observable research state;
7. the request remained failed/incomplete;
8. every acquired work-unit-local resident raster was released;
9. final local resident raster bytes were zero.

No rollback, interruption or request-atomic publication guarantee was required.

## 37. Cancellation evidence

R0.4b-4 deterministically admitted exactly two work units and held both after
successful source materialization.

The coordinator then observed cancellation while both were known active and
resident.

It established:

```text
cancellation observed
    ->
dispatch closed
    ->
no third/fourth work unit starts
    ->
already-running work may complete normally
    ->
request remains cancelled
    ->
final local residency == 0
```

Cancellation was not passed into RasterView, materialization primitives or the
neighbourhood kernel.

No public cancellation-token API was introduced.

## 38. Empty-request evidence

R0.4b-5 established the bounded-parallel zero-work path:

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

No synthetic work unit is created.

## 39. Compiler evidence

At the final R0.4b experiment HEAD before documentation closure:

```text
DMD: 9 modules passed unittests
LDC: 9 modules passed unittests
```

This is current-family verification.

It is not a compiler-floor audit.

## 40. Questions answered by R0.4b

### 40.1 Does concurrency require a richer semantic work-unit object?

Not for the selected operation.

The experiment required a stable research-local work-unit identity for
deterministic synchronization, failure injection and completed-set accounting,
but it did not require promotion of a public WorkUnit/Task type.

### 40.2 Is work-unit-local retention sufficient?

Yes for this first bounded-parallel model.

Independent work-unit-local resident materializations were sufficient.

No shared materialization, shared-reference counting or cache lifetime was
required.

### 40.3 What state is needed to bound active work and residency?

The experiment needed:

- an explicit `maxActiveWorkUnits`;
- current/peak active-work accounting;
- current/peak aggregate resident-raster accounting.

This is sufficient evidence for the tested bounded strategy.

It is not evidence that a work-count limit alone is a universal RAM-budget
policy when future work units have heterogeneous memory requirements.

### 40.4 Is a general scheduler already required?

No.

A disposable coordinator plus bounded batch-local workers was sufficient to
establish the required semantics.

The batch-thread implementation is evidence machinery, not a proposed
production worker-pool architecture.

### 40.5 Is stable work identity useful?

Yes.

Stable identity was required to make failure injection and completion-set
evidence deterministic without depending on execution/completion ordinal.

That does not by itself justify a public task identifier.

### 40.6 What happens to already-running siblings after failure?

Dispatch closes.

Already-running siblings are allowed to reach their ordinary completion
boundary.

Successful siblings may remain completed research state even though the
request fails.

No rollback is implied.

### 40.7 What happens to already-running work after cancellation?

The same non-interruption principle holds in the tested baseline.

Dispatch closes, not-yet-started work remains suppressed, already-running work
may complete normally, and the request remains cancelled.

### 40.8 Is completed-set/coverage sufficient?

Yes for the tested partial-result semantics.

Parallel execution invalidates the R0.4a completed-prefix assumption.

A completed work-unit set plus completed output coverage represented the
observed successful partial work without requiring transactional rollback.

### 40.9 Is output reassembly independent of completion order?

Yes for the selected exact local operation.

R0.4b-2 reassembled in forced completion order `1, 0` and remained
byte-identical to the synchronous oracle.

### 40.10 Which concepts now survive two strategies?

The evidence now supports the following scheduler-neutral distinctions across
both synchronous and bounded-parallel execution:

```text
output request != scheduler task
decomposition != scheduler policy
spatial dependency != execution order
work-unit completion != request completion
logical coordinates != resident coordinates
```

It also supports:

- explicit work-unit-local lifetime;
- completed-set/coverage semantics;
- request-level failure/cancellation termination;
- orchestration-level cancellation observation;
- release of local resident resources before request return.

## 41. Success gate — PASS

All R0.4b success criteria passed:

1. **PASS** — synchronous and bounded-parallel successful output are exactly
   equivalent for the selected operation;
2. **PASS** — bounds 2 and 3 were exercised;
3. **PASS** — real concurrent overlap was proven without timing assumptions;
4. **PASS** — active work never exceeded the configured bound;
5. **PASS** — deterministic out-of-order completion did not change output;
6. **PASS** — aggregate resident-raster accounting is explicit;
7. **PASS** — final local residency is zero on success;
8. **PASS** — final local residency is zero after materialization failure;
9. **PASS** — final local residency is zero after operation failure;
10. **PASS** — final local residency is zero after cancellation;
11. **PASS** — failure suppresses not-yet-started work after observation;
12. **PASS** — cancellation suppresses not-yet-started work after observation;
13. **PASS** — already-running sibling behaviour is explicit and verified;
14. **PASS** — completed work remains distinct from request completion;
15. **PASS** — empty output remains successful zero-work execution;
16. **PASS** — logical coordinates remain distinct from resident coordinates;
17. **PASS** — historical R0.3 evidence remained unchanged;
18. **PASS** — historical R0.4a evidence remained unchanged;
19. **PASS** — production `source/raster/` remained unchanged;
20. **PASS** — no scheduling/cache/provider/image policy was promoted;
21. **PASS** — DMD and LDC produced the same deterministic correctness result.

## 42. Final decision

R0.4b is **complete**.

The R0.4a scheduler-independent semantic contract survived bounded parallel
execution for the selected exact region-local operation.

The experiment did not require:

- a public scheduler;
- a public WorkUnit/Task type;
- a public cancellation token;
- a task graph;
- shared materialization ownership;
- cache policy;
- provider policy;
- image-domain policy.

The experiment therefore does not justify promoting its coordinator, batch
threads, synchronization gates, accounting structs or result types into the
production raster API.

The correct R0.4b decision is:

**Do not promote the R0.4b execution machinery into the production API.**

Keep the experiment as evidence.

Later R0.4 scheduling research may now use the synchronous and bounded-parallel
semantics as reference behaviour while investigating policy such as priority,
fairness and more general worker-pool strategies.
