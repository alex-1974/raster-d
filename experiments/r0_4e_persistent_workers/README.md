# R0.4e Persistent Worker Reuse Experiment

Status: R0.4e-0/R0.4e-1 complete; R0.4e-2 implementation — local compiler validation pending
Date: 2026-09-26
Tracking issue: #20

Contract baseline:

```text
c04040e research: define R0.4e persistent worker contract
6029ca3 research: establish R0.4e worker vocabulary and reuse
e280ddc research: prove R0.4e persistent worker loop
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


R0.4e-1 local compiler evidence:

```text
DMD: 14 modules passed unittests
LDC: 14 modules passed unittests
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

## 13. R0.4e-1 result

R0.4e-1 is complete.

Exactly one OS worker thread was created and started once.

The same persistent `run()` invocation executed:

```text
job 101
job 202
```

with deterministic waiting boundaries between them.

The final evidence was:

```text
runEntries   = 1
waitEntries  = 3
jobsExecuted = 2
trace        = [101, 202]
```

Cooperative shutdown was observed by the same worker and the thread was joined.

No queue, sleep, timeout or polling correctness assumption was introduced.

## 14. R0.4e-2 bounded stage mailboxes

R0.4e-2 introduces two research-local stage-mailbox identities:

```text
materialization
compute
```

The mailbox contract is deliberately smaller than a production queue API.

### 14.1 Push semantics

`tryPush` is non-blocking and returns one of:

```text
none
full
closed
```

Therefore queue-capacity pressure is explicit:

```text
count == capacity
    ->
tryPush == full
```

A rejected full push does not mutate queue contents.

### 14.2 FIFO semantics

Accepted items are removed in insertion order.

The baseline uses stable research work identity and ready ordinal only as
evidence payload.

R0.4e-2 does not reopen R0.4c priority/fairness policy.

### 14.3 Blocking pop

`waitPop` blocks while:

```text
queue empty
and
queue open
```

It wakes when either:

- one item is pushed; or
- the mailbox is closed.

The proof uses a condition variable plus an explicit barrier observation hook so
the coordinator knows the consumer has reached the wait boundary before
triggering the wakeup.

No elapsed-time threshold is used.

### 14.4 Close semantics

`close` means:

```text
reject later pushes
allow already queued items to drain
wake blocked consumers
after drain, waitPop returns closed
```

Closing an already closed mailbox is idempotent.

Mailbox close is not request cancellation.

R0.4d request termination rules remain separate and will be reintroduced with
real persistent raster workers in later slices.

### 14.5 Bounded evidence

The materialization-mailbox fixture uses capacity two and proves:

```text
peakCount == 2
third push while full -> full
pop oldest
push resumes
FIFO trace == [10, 20, 30]
```

The compute-mailbox fixture uses capacity one and one consumer thread to prove:

```text
empty/open -> consumer blocks
push 55 -> consumer wakes with item 55
empty/open -> consumer blocks again
close -> consumer wakes with closed
```

No stage queue grows beyond configured capacity.

R0.4e-2 still does not execute the raster pipeline.

That begins in R0.4e-3.

