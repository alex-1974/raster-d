# R0.4b Bounded Parallel Execution Experiment

Status: experiment contract
Date: 2026-09-25
Tracking issue: #14

Contract baseline:

```text
b9f43f5 research: define R0.4b bounded parallel execution contract
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

## 34. Decision after the experiment

A successful R0.4b result would establish that the same semantic execution
contract survives:

```text
synchronous sequential execution
and
bounded parallel region execution
```

That would strengthen promotion evidence.

It would not automatically justify a public execution framework.

After the experiment, the research must decide explicitly whether:

1. the common semantics justify any production abstraction;
2. execution orchestration should remain internal;
3. more R0.4 evidence is required before promotion.

No decision should be made merely because the experiment contains a working
bounded worker implementation.
