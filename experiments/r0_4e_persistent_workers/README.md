# R0.4e Persistent Worker Reuse Experiment

Status: R0.4e-0 complete; R0.4e-1 implementation — local compiler validation pending
Date: 2026-09-26
Tracking issue: #20

Contract baseline:

```text
c04040e research: define R0.4e persistent worker contract
6029ca3 research: establish R0.4e worker vocabulary and reuse
```

Authoritative research document:

```text
docs/research/execution.md
```


R0.4e-0 local compiler evidence:

```text
DMD: 13 modules passed unittests
LDC: 13 modules passed unittests
```

Nothing in this experiment directory is a stable public API.

## 1. Purpose

R0.4e researches persistent worker reuse for the bounded staged raster
execution model established by R0.4d.

The central separation is:

```text
semantic work
!=
stage readiness
!=
worker assignment
!=
worker lifetime
!=
request lifetime
```

R0.4e-0 defines only vocabulary and verifies historical-reference reuse.

It does not create worker threads.

## 2. Historical evidence boundary

R0.4e must not modify:

```text
source/raster/
experiments/r0_3_regions_streaming/
experiments/r0_4a_synchronous_execution/
experiments/r0_4b_bounded_parallel_execution/
experiments/r0_4c_scheduling_policy/
experiments/r0_4d_pipeline_backpressure/
```

Those sources are immutable evidence for this research slice.

R0.4e may compile and call selected historical research modules.

## 3. Worker vocabulary

R0.4e-0 distinguishes two persistent raster-stage roles:

```text
materialization
compute
```

The first candidate worker lifecycle is:

```text
notStarted
running
waiting
shutdownObserved
joined
```

These names are research vocabulary only.

R0.4e-0 defines no worker-loop transition function.

## 4. Identity boundary

Worker identity and request identity are distinct:

```text
StableWorkerIdentity
StableRequestIdentity
```

A persistent worker may outlive and later serve more than one request.

Therefore:

```text
worker identity
!=
request identity
!=
work-unit identity
```

R0.4e-0 does not yet execute multiple requests.

## 5. Stage-queue vocabulary

The first candidate stage queues are:

```text
materialization queue
compute queue
```

R0.4e-0 defines only explicit finite queue-capacity vocabulary:

```text
materializationQueueCapacity
computeQueueCapacity
```

It does not implement a queue.

Queue bounds do not replace the existing R0.4d execution bounds.

## 6. R0.4e-0 reuse objective

The first executable slice proves only that the new experiment can:

1. compile the persistent-worker vocabulary;
2. compile and call the immutable R0.4a synchronous reference;
3. compile and call the immutable R0.4b bounded-parallel reference;
4. compile and call the immutable R0.4c FIFO policy oracle;
5. compile and exercise the immutable R0.4d pipeline state machine;
6. preserve exact R0.4a/R0.4b output and coverage equality;
7. preserve deterministic R0.4c FIFO order;
8. complete one imported R0.4d state-machine lifecycle with final zero active
   and handoff state.

R0.4e-0 does not prove persistent execution.

## 7. Explicit exclusions

R0.4e-0 contains no:

```text
core.thread.Thread
Barrier
Mutex
Condition
Semaphore
worker loop
queue implementation
work stealing
prefetch
timer
sleep
timeout
```

Persistent-thread behaviour belongs to R0.4e-1.

Bounded queue behaviour belongs to R0.4e-2.

## 8. Initial implementation shape

```text
experiments/r0_4e_persistent_workers/
    README.md
    dub.sdl
    worker_vocabulary.d
    reuse_probe.d
```

## 9. R0.4e evidence slices

### R0.4e-0 — worker vocabulary and reuse boundary

Define worker/request/queue vocabulary and compile historical references.

### R0.4e-1 — persistent worker loop

Prove one persistent worker blocks, wakes, executes multiple jobs, returns to
waiting and shuts down cleanly.

### R0.4e-2 — bounded stage queues

Prove finite queue capacity, deterministic order, queue-full behaviour and
close/wakeup semantics.

### R0.4e-3 — real raster pipeline on persistent workers

Run exact R0.4d staged raster work on persistent workers.

### R0.4e-4 — sequential request reuse

Reuse the same live worker set for multiple successful sequential requests.

### R0.4e-5 — termination recovery

Terminate one request, clean it up and prove a later request succeeds on the
same worker set.

### R0.4e-6 — shutdown and final integration

Wake, stop and join all persistent workers and compare final raster semantics
against historical references.

## 10. Promotion rule

Passing any R0.4e slice does not automatically authorize a public WorkerPool,
Worker, Task, Queue, Executor, Future or ThreadPool API.

## 11. R0.4e-0 result

R0.4e-0 is complete.

It established research-local vocabulary for:

```text
worker role
worker lifecycle
worker identity
request identity
stage-queue kind
stage-queue capacity
```

and compiled/called the immutable R0.4a/R0.4b/R0.4c/R0.4d references.

The R0.4a and R0.4b output/coverage remained exact-equal.

The R0.4c FIFO oracle retained deterministic order.

The imported R0.4d state machine completed one full lifecycle and returned
active/handoff accounting to zero.

No worker thread or queue was introduced.

## 12. R0.4e-1 persistent worker loop

R0.4e-1 introduces exactly one persistent OS worker thread.

The proof sequence is:

```text
thread start
    ->
waiting
    ->
job 101
    ->
waiting
    ->
job 202
    ->
waiting
    ->
shutdown observed
    ->
thread return
    ->
join
```

The worker thread is created exactly once.

Both jobs execute inside the same invocation of the persistent worker loop.

The test records:

```text
runEntries
waitEntries
jobsExecuted
executionTrace
shutdownObserved
```

and requires:

```text
runEntries == 1
jobsExecuted == 2
executionTrace == [101, 202]
```

The worker uses three reusable explicit synchronization gates:

- a waiting gate so the coordinator knows the worker reached the waiting state;
- a command gate that releases exactly one pending command;
- a completion gate that reports one command boundary.

These are deterministic research gates.

R0.4e-1 does not implement a stage queue.

No sleep, timeout, polling loop or wall-clock threshold is used.

After shutdown the coordinator joins the one worker thread and records the
final lifecycle state as:

```text
joined
```

R0.4e-1 proves persistent thread reuse only.

Queue bounds and queue-full semantics remain R0.4e-2.

