# R0.4c Scheduling Policy Experiment

Status: experiment contract
Date: 2026-09-25
Tracking issue: #16

Contract baseline:

```text
189cf56 research: define R0.4c scheduling policy contract
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
