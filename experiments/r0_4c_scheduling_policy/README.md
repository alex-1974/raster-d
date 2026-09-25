# R0.4c Scheduling Policy Experiment

Status: R0.4c evidence complete
Date: 2026-09-25
Tracking issue: #16

Contract baseline:

```text
189cf56 research: define R0.4c scheduling policy contract
```

Evidence commits:

```text
d81ea80 research: prove R0.4c reuse of execution evidence
f490bb2 research: prove R0.4c FIFO scheduling baseline
083e9de research: prove R0.4c strict priority scheduling
bfdcbef research: prove R0.4c strict priority starvation
fe1dd02 research: prove R0.4c bounded interactive preference
8f2d3e2 research: prove R0.4c termination admission gate
dbed0dd research: prove R0.4c raster policy integration
```

Authoritative research document:

```text
docs/research/execution.md
```

Nothing in this experiment directory is a stable public API.

## 1. Purpose

R0.4c researches scheduling policy above the execution semantics already
established by R0.4a and R0.4b.

The central separation is:

```text
what work is semantically required
!=
which ready work is admitted next
```

The experiment must determine whether deterministic ready-work selection can
express:

- FIFO ordering;
- strict priority;
- starvation evidence;
- starvation-resistant preference;
- request-termination admission closure;

without changing raster geometry, dependency semantics, operation semantics,
ownership/lifetime rules or request-completion semantics.

## 2. Research boundary

R0.4c must not modify:

```text
source/raster/
experiments/r0_3_regions_streaming/
experiments/r0_4a_synchronous_execution/
experiments/r0_4b_bounded_parallel_execution/
```

Historical R0.3/R0.4a/R0.4b evidence remains immutable.

The first policy model operates only on already-ready synthetic work metadata.

It does not model:

- dependency readiness;
- pipeline stages;
- asynchronous I/O;
- decode/materialize/compute staging;
- work stealing;
- prefetch;
- provider/source policy;
- cache replacement;
- preemptive execution;
- OS thread priority;
- CPU affinity;
- GPU scheduling;
- imagery-specific scheduling.

It does not promote:

- a public Scheduler;
- a public Priority;
- a public WorkClass;
- a public FairnessPolicy;
- a public Task;
- a public WorkUnit.

## 3. Inherited execution semantics

R0.4c inherits these distinctions unchanged:

```text
output request != scheduler task
decomposition != scheduler policy
spatial dependency != execution order
work-unit completion != request completion
logical coordinates != resident coordinates
```

It also inherits:

- bounded active work;
- work-unit-local resource lifetime;
- completed-set/coverage semantics;
- failure/cancellation closing dispatch;
- no forced interruption of already-running work;
- zero-work request success;
- final release of local resident state.

Scheduling policy may choose among ready work but may not redefine those rules.

## 4. Policy metadata

The first experiment may use research-local metadata equivalent to:

```text
stableWorkUnitId
readyOrdinal
policyClass
priority
```

These are policy-oracle inputs only.

They must not be added to Region2D, RasterView, dependency structures or raster
operation APIs.

Stable work identity remains distinct from:

```text
ready ordinal
dispatch ordinal
completion ordinal
```

## 5. Determinism

Policy evidence must not depend on:

- sleep;
- wall-clock delays;
- operating-system thread scheduling;
- machine speed;
- pointer identity;
- hash iteration order.

The first slices should use a deterministic ready-work oracle.

Equal policy metadata should use a stable ready-order tie-break.

## 6. Candidate P0 — FIFO

P0 selects the lowest ready ordinal first.

Required evidence:

- stable ordering;
- deterministic equal-class behaviour;
- no hidden priority effect.

## 7. Candidate P1 — strict priority

P1 selects the highest-priority ready work first.

Equal priority falls back to stable ready order.

Required evidence:

- deterministic priority preference;
- stable tie-breaking;
- explicit starvation/bypass behaviour under sustained higher-priority arrivals.

## 8. Candidate P2 — starvation-resistant preference

The first preferred candidate is bounded priority burst/quota.

Research form:

```text
while throughput is continuously ready:
    admit at most N consecutive interactive work units
    then admit one throughput work unit
```

The exact burst N is experiment configuration.

The policy must preserve interactive preference while providing an explicit,
deterministic throughput progress bound.

This is an experiment candidate, not a production-policy choice.

## 9. Fairness metric

Initial fairness evidence is based on dispatch opportunities.

Useful measurements include:

```text
dispatch opportunities bypassed
service count by class
maximum consecutive admissions by class
stable order within class
```

The experiment must preserve this distinction:

```text
dispatch fairness
!=
CPU-time fairness
```

No CPU-time fairness claim is permitted unless later research models work cost
explicitly.

## 10. Non-preemption

R0.4c initially researches admission order only.

Once a work unit is admitted, the R0.4b baseline remains:

> Running work is not forcibly interrupted by policy.

No preemptive scheduler is part of this experiment.

## 11. Request termination

Failure/cancellation remains stronger than policy preference.

Once request termination is observed:

```text
dispatch closes
```

No FIFO, priority or fairness rule may admit later work.

The first experiment must prove this independently of which policy is selected.

## 12. Active-work and residency boundary

Policy selection may feed bounded execution but must not authorize:

```text
currentActiveWorkUnits > maxActiveWorkUnits
```

The first policy oracle may dispatch one opportunity at a time.

A later integration slice must demonstrate that policy-selected order can feed
R0.4b-compatible bounded execution without changing the active-work bound.

R0.4c preserves:

```text
bounded active-work count
!=
general resident-byte budget
```

Priority/fairness is not a memory-budget controller.

## 13. R0.4a/R0.4b reuse

Preferred dependency direction:

```text
R0.4c experiment
    ->
R0.4b bounded-parallel reference
    ->
R0.4a synchronous reference
    ->
selected immutable R0.3 research modules
    ->
production raster-d API
```

R0.4c may compile and call immutable R0.4a/R0.4b research modules.

It must not edit them merely to make policy research easier.

## 14. R0.4c-0 reuse probe

The first executable slice proves only that R0.4c can:

1. compile the immutable R0.4b bounded-parallel executor;
2. compile the immutable R0.4a synchronous executor;
3. execute both against the same legal decomposition;
4. obtain the same exact output;
5. observe successful request completion and final zero local residency.

No FIFO/priority/fairness implementation belongs in R0.4c-0.

## 15. Initial implementation shape

Start with:

```text
experiments/r0_4c_scheduling_policy/
    README.md
    dub.sdl
    reuse_probe.d
```

Later slices may add one policy-oracle module.

Additional modules require a separate reason.

The experiment must not grow into a reusable scheduler framework.

## 16. Evidence slices

### R0.4c-0 — vocabulary and reuse

Prove immutable R0.4a/R0.4b reuse.

### R0.4c-1 — FIFO

Prove deterministic stable ready-order dispatch.

### R0.4c-2 — strict priority

Prove priority preference and stable tie-breaking.

### R0.4c-3 — starvation

Prove sustained high-priority arrivals can indefinitely bypass continuously
ready lower-priority work under strict priority.

### R0.4c-4 — starvation-resistant preference

Prove one minimal policy gives an explicit deterministic progress bound while
retaining interactive preference.

### R0.4c-5 — termination gate

Prove failure/cancellation closes admission for every tested policy.

### R0.4c-6 — raster integration

Use at least two legal policy orders with an exact R0.4b-compatible raster
operation and prove byte-identical output plus preserved active-work bound.

## 17. Initial result matrix

| Case | Policy | Required evidence |
| --- | --- | --- |
| equal ready work | FIFO | stable ready order |
| mixed priority | strict priority | high priority preferred |
| sustained high arrivals | strict priority | starvation/bypass observable |
| sustained interactive arrivals | starvation-resistant | throughput progress bounded |
| equal metadata | all candidates | deterministic tie-break |
| terminated request | all candidates | no later dispatch |
| raster integration | multiple policy orders | exact output equality |
| bounded integration | selected policy | active bound preserved |

## 18. Success gate

R0.4c is complete only if:

1. FIFO ready-order behaviour is deterministic;
2. strict priority prefers higher-priority ready work deterministically;
3. strict-priority starvation/bypass is demonstrated under sustained load;
4. one starvation-resistant policy provides an explicit progress bound;
5. interactive work retains measurable preference;
6. throughput work still progresses under sustained interactive arrivals;
7. equal policy metadata has a stable deterministic tie-break;
8. fairness/starvation evidence uses dispatch opportunities, not wall-clock time;
9. request termination suppresses later dispatch for every tested policy;
10. policy metadata remains research-local;
11. bounded execution still respects maxActiveWorkUnits;
12. policy order does not change exact raster output;
13. historical R0.3/R0.4a/R0.4b evidence remains unchanged;
14. production source/raster remains unchanged;
15. no pipeline/work-stealing/prefetch/provider/image policy is promoted;
16. DMD and LDC produce the same deterministic correctness result.

## 19. Promotion rule

Passing R0.4c does not authorize a public scheduler-policy API.

Promotion requires a concrete consumer and evidence that the abstraction
remains useful across multiple policies and later execution/source research.

Until then, all R0.4c policy types and algorithms remain disposable research
machinery.

## 20. Measured result matrix

| Case | Policy | Measured result |
| --- | --- | --- |
| reuse probe | R0.4a + R0.4b | exact output equality; final local residency 0 |
| stable ready set | FIFO | dispatch follows ascending readyOrdinal |
| mixed priorities | strict priority | highest numeric priority first; readyOrdinal tie-break |
| sustained higher-priority arrivals | strict priority | continuously ready throughput bypassed at every tested opportunity |
| sustained interactive arrivals | bounded burst | maximum throughput bypass equals configured burst N |
| terminated request | all three policies | no later selection/admission |
| raster integration | FIFO | exact R0.4a output; R0.4b active bound preserved |
| raster integration | strict priority | exact R0.4a output; R0.4b active bound preserved |
| raster integration | bounded burst | exact R0.4a output; R0.4b active bound preserved |

## 21. FIFO evidence

R0.4c-1 established the policy baseline:

```text
lowest readyOrdinal first
```

`policyClass` and `priority` are deliberately ignored by FIFO.

Stable identity and ready ordinal are required to be unique inside the tested
ready set. Ambiguous metadata is rejected instead of repaired by a hidden
secondary order.

An empty ready set is a valid zero-dispatch state.

## 22. Strict-priority evidence

R0.4c-2 established:

```text
highest priority first
then lowest readyOrdinal
```

The full `int` priority domain was exercised.

`policyClass` remains descriptive metadata for P1; strict priority is driven by
numeric priority and contains no aging, quota or fairness state.

## 23. Starvation evidence

R0.4c-3 used one continuously ready lower-priority throughput item and made a
fresh higher-priority interactive item ready before every dispatch opportunity.

For observation horizons:

```text
1, 2, 8, 32, 128
```

the result was always:

```text
bypassedOpportunities == dispatchOpportunities
lowerPriorityDispatched == false
```

This demonstrates that strict priority provides no finite bypass bound of its
own.

The claim is dispatch-opportunity starvation evidence, not elapsed-time
starvation evidence.

## 24. Starvation-resistant bounded-burst evidence

R0.4c-4 introduced the first deliberate policy state:

```text
maxInteractiveBurst
consecutiveInteractiveAdmissions
```

While throughput remains continuously ready:

```text
admit at most N consecutive interactive items
then admit one throughput item
```

For tested bursts:

```text
N = 1, 2, 3, 8
```

the measured result was:

```text
maxObservedThroughputBypass == N
```

with repeated throughput service under sustained interactive arrivals.

Interactive preference remains explicit: after reset, interactive work is
selected while both classes are ready, even when the throughput item's numeric
priority is higher.

Inside the selected class, ordering remains:

```text
highest priority
then lowest readyOrdinal
```

This is dispatch fairness only.

```text
dispatch fairness
!=
CPU-time fairness
```

No execution-cost or elapsed-time model was introduced.

## 25. Termination-gate evidence

R0.4c-5 placed request termination ahead of scheduling policy:

```text
failure/cancellation observed
    ->
dispatch closed
    ->
do not consult policy
    ->
no later admission
```

The rule was verified for:

- FIFO;
- strict priority;
- bounded interactive burst.

Closed dispatch also prevents bounded-burst fairness state from advancing.

Termination dominates policy validation: once dispatch is closed, even
policy-invalid ready metadata or an invalid P2 configuration cannot reopen
admission.

The first observed terminal reason remains stable.

## 26. Raster integration evidence

R0.4c-6 mapped stable work identity onto the immutable six-member R0.4b
decomposition and produced three distinct legal orders:

```text
FIFO:
0, 1, 2, 3, 4, 5

strict priority:
3, 5, 1, 4, 2, 0

bounded burst:
3, 5, 4, 1, 2, 0
```

All three policy orders were passed unchanged to the immutable R0.4b bounded
executor with:

```text
maxActiveWorkUnits = 2
```

For every policy:

```text
policy result output == R0.4a synchronous output
completedCoverage == R0.4a completedCoverage
peakActiveWorkUnits <= maxActiveWorkUnits
currentResidentRasterBytes == 0
```

Therefore, for the selected exact independent raster operation:

```text
scheduling policy order
!=
semantic raster result
```

## 27. Compiler evidence

At the final R0.4c experiment HEAD before documentation closure:

```text
DMD: 11 modules passed unittests
LDC: 11 modules passed unittests
```

This is current-family verification.

It is not yet the pull-request compiler-floor matrix.

## 28. R0.4c questions answered

### 28.1 Smallest policy input beyond stable work identity

For the tested evidence, the useful research-local vocabulary is:

```text
stableWorkUnitId
readyOrdinal
policyClass
priority
```

Individual policies use only the subset they need.

FIFO needs ready order. Strict priority adds numeric priority. The
starvation-resistant candidate additionally uses class membership and small
policy-local class-progress state.

### 28.2 Is two-class interactive/throughput sufficient?

Yes for the first starvation/fairness evidence.

Two classes were sufficient to distinguish preferred work from work that must
still make bounded progress.

This does not prove that two classes are sufficient for a future product
scheduler.

### 28.3 Is FIFO a useful baseline?

Yes.

FIFO gives a deterministic policy reference with no hidden priority effect and
a stable ready-order tie-break.

### 28.4 How severe is strict-priority starvation?

Strict priority has no finite bypass bound in the tested sustained-arrival
model.

For every tested horizon, the continuously ready lower-priority item was
bypassed at every dispatch opportunity.

### 28.5 Simplest starvation-resistant candidate

A bounded interactive burst was sufficient for first evidence.

It required only configured burst size plus one consecutive-admission counter.

It preserved interactive preference while bounding throughput bypass.

This is not a production-policy selection.

### 28.6 How is fairness measured without wall-clock time?

By deterministic dispatch opportunities and service counts.

The experiment measures maximum consecutive bypass and class admissions, not
CPU time.

### 28.7 What fairness state is required?

For the tested bounded-burst candidate, no per-work-unit aging state was
required.

Small policy/class-level state was sufficient:

```text
maxInteractiveBurst
consecutiveInteractiveAdmissions
```

### 28.8 Can policy remain independent of raster geometry?

Yes for this evidence.

FIFO, strict priority, starvation and fairness logic operate entirely on
research-local policy metadata.

No policy metadata was added to Region2D, RasterView, dependency structures or
raster operation signatures.

### 28.9 Can request termination close admission independently of policy?

Yes.

The termination gate executes before policy selection and was verified against
all three policies.

### 28.10 Does policy integration preserve exact raster output?

Yes for the selected exact independent raster operation.

Three distinct legal policy orders produced byte-identical output and coverage
while preserving the R0.4b active-work bound.

### 28.11 Does any scheduler-policy abstraction deserve promotion?

Not yet.

The evidence supports semantic separation and useful internal vocabulary, but
there is still no concrete production consumer requiring a public Scheduler,
Priority, WorkClass or FairnessPolicy API.

## 29. Success gate — PASS

All sixteen R0.4c gates passed:

1. **PASS** — FIFO ready-order behaviour is deterministic;
2. **PASS** — strict priority deterministically prefers higher-priority ready work;
3. **PASS** — strict-priority starvation/bypass is demonstrated under sustained load;
4. **PASS** — bounded interactive burst provides an explicit deterministic progress bound;
5. **PASS** — interactive work retains measurable preference;
6. **PASS** — throughput work progresses under sustained interactive arrivals;
7. **PASS** — equal policy metadata has stable ready-order tie-breaking;
8. **PASS** — fairness/starvation evidence uses dispatch opportunities, not wall-clock timing;
9. **PASS** — failure/cancellation suppresses later dispatch for every tested policy;
10. **PASS** — policy metadata remains research-local;
11. **PASS** — bounded raster integration respects `maxActiveWorkUnits`;
12. **PASS** — policy order does not change exact raster output;
13. **PASS** — historical R0.3/R0.4a/R0.4b evidence remained unchanged;
14. **PASS** — production `source/raster/` remained unchanged;
15. **PASS** — no pipeline/work-stealing/prefetch/provider/image policy was promoted;
16. **PASS** — DMD and LDC produced the same deterministic correctness result.

## 30. Final decision

R0.4c is **complete**.

The evidence establishes that scheduling policy can vary independently of the
R0.4a/R0.4b execution semantics for the selected operation.

The following distinctions now have direct evidence:

```text
semantic work != policy metadata
ready order != priority order
dispatch preference != fairness guarantee
dispatch fairness != CPU-time fairness
request termination > policy preference
policy order != semantic raster output
```

The correct R0.4c promotion decision is:

**Do not promote the R0.4c scheduling-policy machinery into the production raster API.**

Keep FIFO, strict-priority, bounded-burst, termination-gate and policy-metadata
types as research evidence.

R0.4d may now investigate pipeline parallelism and stage/backpressure semantics
while preserving the R0.4a/R0.4b/R0.4c reference behaviour.
