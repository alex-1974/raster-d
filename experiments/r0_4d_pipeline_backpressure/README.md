# R0.4d Bounded Pipeline Backpressure Experiment

Status: R0.4d-0 through R0.4d-5 complete; R0.4d-6 implementation — local compiler validation pending
Date: 2026-09-25
Tracking issue: #18

Contract baseline:

```text
52b7df0 research: define R0.4d pipeline backpressure contract
```


Evidence commits:

```text
e9f8665 research: establish R0.4d pipeline vocabulary and reuse
d76f921 research: prove R0.4d deterministic pipeline state machine
68b1ccc research: prove R0.4d bounded pipeline stage overlap
1319838 research: prove R0.4d deterministic backpressure
c06ae73 research: prove R0.4d stage-order independence
43196c7 research: prove R0.4d termination cleanup
```

R0.4d-0 local compiler evidence:

```text
DMD: 11 modules passed unittests
LDC: 11 modules passed unittests
```


R0.4d-1 local compiler evidence:

```text
DMD: 12 modules passed unittests
LDC: 12 modules passed unittests
```


R0.4d-2 local compiler evidence:

```text
DMD: 13 modules passed unittests
LDC: 13 modules passed unittests
```


R0.4d-3 local compiler evidence:

```text
DMD: 14 modules passed unittests
LDC: 14 modules passed unittests
```


R0.4d-4 local compiler evidence:

```text
DMD: 15 modules passed unittests
LDC: 15 modules passed unittests
```


R0.4d-5 local compiler evidence:

```text
DMD: 16 modules passed unittests
LDC: 16 modules passed unittests
```

Authoritative research document:

```text
docs/research/execution.md
```

Nothing in this experiment directory is a stable public API.

## 1. Purpose

R0.4d researches bounded staged raster execution above the semantic references
already established by R0.4a, R0.4b and R0.4c.

The central separation is:

```text
semantic work
!=
pipeline stage
!=
stage admission / backpressure
```

R0.4d does not research a general-purpose pipeline, DAG, workflow or async task
framework.

Every stage admitted to this experiment must exist because of a generic raster
execution requirement.

## 2. Raster-d scope gate

Use this boundary test throughout R0.4d:

```text
Would the abstraction still make sense if the raster represented
elevation, temperature or another scientific grid instead of an image?

YES  -> candidate raster-d mechanism
NO   -> higher-level consumer / adapter concern
```

The experiment may know about:

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

It must not know about:

```text
JPEG / TIFF codec semantics
GDALDataset
COG / HTTP / WMS / WMTS policy
RGB / Lab / ICC semantics
alpha interpretation
radiometry
sensor/acquisition metadata
CRS / geotransform / GSD
imagery mosaicking policy
image-specific enhancement semantics
OSM/application workflow semantics
```

## 3. Historical evidence boundary

R0.4d must not modify:

```text
source/raster/
experiments/r0_3_regions_streaming/
experiments/r0_4a_synchronous_execution/
experiments/r0_4b_bounded_parallel_execution/
experiments/r0_4c_scheduling_policy/
```

Those sources are immutable evidence for this research slice.

R0.4d may compile and call selected historical research modules.

## 4. Initial stage vocabulary

The research-local lifecycle vocabulary is:

```text
notAdmitted
materializing
readyForCompute
computing
completed
released
```

R0.4d-0 defines only names and resource-limit vocabulary.

It does not yet implement stage transitions.

Per-work-unit transition legality belongs to R0.4d-1.

## 5. Initial bounded-resource vocabulary

The first pipeline model uses:

```text
maxActiveWorkUnits
maxMaterializing
maxComputing
handoffCapacity
```

The intended later invariants are:

```text
activeWorkUnits <= maxActiveWorkUnits
materializing <= maxMaterializing
computing <= maxComputing
materializing + readyForCompute <= handoffCapacity
```

R0.4d-0 does not yet implement or claim those counters.

The distinction remains explicit:

```text
bounded pipeline slots
!=
bounded resident bytes
```

## 6. Handoff-credit vocabulary

A handoff credit is downstream holding capacity reserved before materialization
starts.

The later intended rule is:

```text
reserve handoff credit
    before
start materialization
```

and:

```text
compute starts
    ->
release that work unit's handoff credit
```

This prevents upstream materialization from producing resident work with no
bounded place to wait.

R0.4d-0 defines this vocabulary only.

Reservation/release mechanics belong to R0.4d-1 and later evidence.

## 7. R0.4d-0 reuse objective

The first executable slice proves only that the new experiment can:

1. compile the R0.4d vocabulary;
2. compile and call the immutable R0.4a synchronous reference;
3. compile and call the immutable R0.4b bounded-parallel reference;
4. compile and call the immutable R0.4c FIFO policy oracle;
5. run R0.4a and R0.4b against the same legal decomposition;
6. obtain exact output and coverage equality;
7. observe final zero local raster residency;
8. preserve the R0.4b active-work bound;
9. preserve deterministic R0.4c FIFO order.

R0.4d-0 does not prove pipeline execution.

## 8. Initial implementation shape

```text
experiments/r0_4d_pipeline_backpressure/
    README.md
    dub.sdl
    pipeline_vocabulary.d
    reuse_probe.d
```

No queue, worker pool, semaphore, barrier or thread belongs in R0.4d-0.

## 9. Determinism

R0.4d correctness evidence must not depend on:

- sleep;
- elapsed time;
- timeout races;
- operating-system scheduling order;
- machine speed;
- pointer identity;
- unordered hash iteration.

Later concurrency slices may use explicit synchronization to force states and
ordering.

## 10. R0.4d evidence slices

### R0.4d-0 — vocabulary and reuse

Compile historical references and establish stage/backpressure terminology.

### R0.4d-1 — deterministic state machine

Prove legal stage transitions and bounded counter/credit mechanics without
threads.

### R0.4d-2 — bounded pipeline success

Prove real materialize/compute overlap across different work units while
preserving exact raster output and configured bounds.

### R0.4d-3 — deterministic backpressure

Use explicit synchronization to prove a full handoff bound blocks upstream
materialization and released credit resumes progress.

### R0.4d-4 — stage-order independence

Force out-of-order stage completion and prove output/coverage invariance.

### R0.4d-5 — failure/cancellation cleanup

Prove dispatch/stage closure and release semantics at controlled stage
boundaries.

### R0.4d-6 — raster integration

Compare the final bounded pipeline against the exact R0.4a and bounded R0.4b
references.

## 11. Explicit non-goals

R0.4d does not implement:

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

## 12. Promotion rule

Passing R0.4d will not automatically authorize a public Pipeline, Stage, Queue,
BackpressureController, Executor, Graph or Workflow API.

Until a separate production promotion decision is justified, every R0.4d type
remains disposable research machinery.

## 13. R0.4d-0 result

R0.4d-0 is complete.

It proved that the new experiment can compile and execute the immutable R0.4a
and R0.4b references, compile/call the immutable R0.4c FIFO oracle, preserve
exact output/coverage equality, preserve the R0.4b active-work bound and finish
with zero local raster residency.

No pipeline execution semantics were introduced in R0.4d-0.

## 14. R0.4d-1 deterministic state machine

R0.4d-1 introduces research-local, single-threaded transition semantics.

The first legal success path is:

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

Starting materialization is also pipeline admission and must reserve one handoff
credit.

The credit remains reserved across:

```text
materializing
readyForCompute
```

and is released only when compute starts.

The accounting model tracks:

```text
activeWorkUnits
materializing
readyForCompute
computing
completedPendingRelease
handoffCreditsInUse
```

with exact accounting identities:

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

The configured bounds remain:

```text
activeWorkUnits <= maxActiveWorkUnits
materializing <= maxMaterializing
computing <= maxComputing
handoffCreditsInUse <= handoffCapacity
```

A rejected transition must not mutate either work-unit stage or global
accounting.

R0.4d-1 remains single-threaded. It does not prove concurrent execution.

## 15. R0.4d-1 result

R0.4d-1 is complete.

The single-threaded state machine proved:

- exact per-work-unit success-stage ordering;
- admission and active-work limits;
- materialization-stage limits;
- compute-stage limits;
- reservation-before-materialization handoff semantics;
- handoff credit retention across `materializing -> readyForCompute`;
- handoff credit release at compute start;
- explicit completed-but-not-yet-released ownership;
- exact accounting identities;
- mutation-free rejected transitions;
- zero-capacity/zero-work consistency.

No concurrency claim was made by R0.4d-1.

## 16. R0.4d-2 bounded pipeline success

R0.4d-2 introduces real OS-thread concurrency for one narrow success fixture.

The configured limits are deliberately:

```text
maxActiveWorkUnits = 2
maxMaterializing  = 1
maxComputing      = 1
handoffCapacity   = 1
```

The deterministic overlap sequence is:

```text
A materialize
A readyForCompute
A start compute
    -> releases the only handoff credit
B start materialize
    ->
A computing && B materializing
```

Two worker threads then enter those different active stage bodies and wait on
explicit shared barriers.

The coordinator reaches the same barrier only after both workers have entered.

Therefore overlap evidence does not depend on sleep, elapsed time or OS
scheduler luck.

After the coordinator records the overlap state, a second barrier releases both
stage bodies.

R0.4d-2 performs real raster work:

- A computes the established exact weighted 3 x 3 neighbourhood operation
  against an already materialized procedural source;
- B simultaneously materializes its procedural source;
- B later computes the same operation;
- both task outputs are assembled into the requested output;
- the complete result is compared byte-for-byte with R0.4a.

The resident compute helper is R0.4d-local orchestration over established public
research components. It is not a promoted production primitive.

R0.4d-2 still does not introduce a queue, reusable worker pool, dynamic stage
selection or general pipeline API.

## 17. R0.4d-2 result

R0.4d-2 is complete.

It proved real cross-stage concurrency with explicit synchronization:

```text
work A: computing
work B: materializing
```

at the same observed point.

The proof executed real procedural materialization and the established exact
weighted 3 x 3 neighbourhood operation.

The assembled result and completed coverage were byte-identical to the R0.4a
synchronous semantic reference.

Configured active/materialize/compute/handoff bounds were preserved and final
research-local active, handoff and resident-raster state returned to zero.

No timing assumption was used.

## 18. R0.4d-3 deterministic backpressure

R0.4d-3 isolates the backpressure mechanism from raster arithmetic.

The fixture uses:

```text
maxActiveWorkUnits = 3
maxMaterializing  = 2
maxComputing      = 1
handoffCapacity   = 2
```

Two work units are advanced to `readyForCompute`, producing:

```text
readyForCompute      = 2
handoffCreditsInUse  = 2
```

A third otherwise-admissible work unit must then fail specifically with:

```text
handoffCapacityReached
```

and the rejected transition must mutate neither the third work state nor global
accounting.

Next, compute starts for the first ready work unit.

That transition releases exactly one handoff credit.

A dedicated compute-stage worker then enters and remains blocked on an explicit
barrier so downstream compute is deterministically still in flight.

While that compute stage is held, the exact same third upstream work unit must
now be admitted into materialization successfully.

This proves:

```text
full handoff capacity
    ->
upstream start blocked

compute start
    ->
one handoff credit released

released credit
    ->
upstream start resumes
```

The proof uses no sleep, timeout or wall-clock threshold.

R0.4d-3 still introduces no queue, worker pool or general backpressure API.

## 19. R0.4d-3 result

R0.4d-3 is complete.

It proved deterministic handoff backpressure:

```text
handoff full
    ->
otherwise-admissible upstream start rejected

compute start
    ->
one handoff credit released

same upstream work unit
    ->
admitted successfully while compute remains in flight
```

The blocked attempt was mutation-free.

The configured limits were reached but never exceeded, and final accounting
returned to zero.

No sleep, timeout or wall-clock threshold was used.

## 20. Shared R0.4d raster-stage fixture

Before R0.4d-4, the retained procedural-source fixture and exact resident
neighbourhood compute orchestration are factored into:

```text
pipeline_raster_fixture.d
```

This is a research-local refactor only.

It prevents later R0.4d slices from copying the same logical-to-resident
mapping and retained-source lifetime code.

R0.4d-2 is changed only to consume this shared experiment-local fixture.

Nothing is promoted into `source/raster/`.

## 21. R0.4d-4 stage-order independence

R0.4d-4 runs the same two-work-unit exact raster request twice.

Both work units are first advanced to:

```text
computing
computing
```

with:

```text
maxActiveWorkUnits = 2
maxMaterializing  = 2
maxComputing      = 2
handoffCapacity   = 2
```

Two real compute workers enter a common start barrier.

Each worker then has its own explicit release and completion barriers.

Run A forces:

```text
work 0 compute completion
before
work 1 compute completion
```

Run B forces:

```text
work 1 compute completion
before
work 0 compute completion
```

After the first forced completion:

```text
requestCompleted == false
```

because one work unit is still active and coverage is incomplete.

Only after the second completion, semantic output commit and explicit release:

```text
requestCompleted == true
```

Both forced completion orders must produce:

- byte-identical output to each other;
- byte-identical output to R0.4a;
- identical completed coverage;
- final zero active/handoff state;
- final zero retained fixture residency.

The completion trace is evidence only.

It does not define semantic output order.

No sleep or timing threshold is used.

## 22. R0.4d-4 result

R0.4d-4 is complete.

Two real compute workers were advanced to `computing` simultaneously and then
forced, using independent explicit barriers, to complete in both orders:

```text
0 -> 1
1 -> 0
```

After the first completion in either run, request completion remained false.

After the second completion, output commit and release, request completion
became true.

Both forced completion orders produced exact R0.4a output and coverage, and
both ended with zero active/handoff/resident state.

No timing assumption was used.

## 23. R0.4d-5 termination and cleanup

R0.4d-5 introduces one request-local termination gate with reasons:

```text
open
failed
cancelled
```

The first terminal reason wins.

The gate is checked before:

```text
new materialization admission
new compute start
```

A closed gate does not preempt a stage body that already started.

### Failure while materializing

A real materialization worker is held in-flight by explicit barriers.

Failure is observed while that stage remains running.

After failure:

- a new work unit cannot enter materialization;
- the already-running materialization is released and allowed to finish;
- its resulting resident raster may reach `readyForCompute`;
- compute start is rejected by the closed gate;
- retained resident state is released;
- the state machine uses `readyForCompute -> released` cleanup;
- final active/handoff/resident state returns to zero.

### Cancellation while computing

Two work units are first materialized.

One starts compute.

The other remains `readyForCompute`.

The running compute worker is then held in-flight by explicit barriers and
cancellation is observed.

After cancellation:

- the queued ready work unit cannot start compute;
- a new work unit cannot enter materialization;
- the already-running compute is allowed to finish;
- that completed running work may publish its output/coverage;
- the queued resident raster is released without compute;
- request completion remains false because coverage is only partial;
- final active/handoff/resident state returns to zero.

The new state-machine cleanup transition:

```text
readyForCompute
    ->
released
```

exists only for retained-work termination cleanup.

R0.4d-5 does not add stage preemption, exceptions, timeouts, worker pools or a
public cancellation API.

## 24. R0.4d-5 result

R0.4d-5 is complete.

It proved request-local failure/cancellation stage-start closure while
preserving non-preemption of already-running materialization/compute bodies.

Retained ready-for-compute work can be released without starting compute after
termination, and all tested termination paths end with zero active, handoff and
retained resident state.

A running compute may finish and publish partial coverage after cancellation,
but request completion remains false when required coverage is incomplete.

No timing assumption was used.

## 25. R0.4d-6 raster integration

R0.4d-6 reuses the canonical six-member legal decomposition already used by
R0.4c integration:

```text
requestedOutput = Region2D(1020, 2030, 8, 6)

work 0 = Region2D(1020, 2030, 8, 1)
work 1 = Region2D(1020, 2031, 3, 2)
work 2 = Region2D(1023, 2031, 5, 2)
work 3 = Region2D(1020, 2033, 5, 2)
work 4 = Region2D(1025, 2033, 3, 2)
work 5 = Region2D(1020, 2035, 8, 1)
```

The same semantic request is executed by:

```text
R0.4a synchronous reference
R0.4b bounded-parallel reference, maxActiveWorkUnits = 2
R0.4d bounded staged integration
```

The R0.4d limits are:

```text
maxActiveWorkUnits = 2
maxMaterializing  = 1
maxComputing      = 1
handoffCapacity   = 1
```

The staged run primes work 0 by materializing it first.

It then pipelines each adjacent pair:

```text
compute(i)
    overlaps
materialize(i + 1)
```

using explicit barriers.

With six work units, exactly five cross-stage overlap pairs are observed.

The final work unit drains the pipeline without a successor materialization.

The integration must prove:

- exact output equality across R0.4a, R0.4b and R0.4d;
- exact completed-coverage equality across all three;
- R0.4d request completion;
- R0.4b request completion;
- R0.4d peak active work equals two and never exceeds its limit;
- R0.4d materializing peak equals one;
- R0.4d computing peak equals one;
- R0.4d handoff-credit peak equals one;
- five deterministic cross-stage overlap observations;
- final R0.4d active/handoff state is zero;
- final R0.4d retained resident bytes are zero;
- R0.4b final resident bytes are zero.

This is a research-local linear staged raster runner.

It is not promoted as a general executor, worker pool, queue, DAG or workflow
API.

