# raster-d v0.2 M5.5 — persistent-worker research reconciliation

Status: complete.

## Goal

M5.5 reconciles the grandfathered
`research/r0_4e-persistent-workers` evidence with the workspace rule that
fundamental libraries keep scheduling caller-owned by default.

The result is intentionally an architectural boundary decision. It does not
promote a raster-d worker pool, executor or scheduler.

## Workspace contract

The canonical workspace principles require:

- threading behaviour to be documented;
- no hidden worker threads unless intrinsic to the library domain;
- application/caller ownership of scheduling by default;
- independent work to be expressible so callers can parallelise it where
  practical;
- deterministic externally visible behaviour where practical.

R0.4e is grandfathered pre-migration research evidence and remains unchanged.

## R0.4e evidence retained

R0.4e successfully proved, under DMD and LDC:

- persistent OS worker reuse across multiple jobs;
- worker lifetime distinct from request and work-unit lifetime;
- bounded FIFO stage mailboxes;
- explicit queue-full and closed behaviour;
- deterministic blocking/wakeup without timeout-based correctness;
- sequential request reuse on one live worker set;
- cancellation/failure cleanup followed by successful later requests;
- clean shutdown, wakeup and join;
- exact raster output/coverage equality against synchronous and bounded-parallel
  historical references;
- no retained raster bytes after completed/terminated requests.

These results remain valuable engineering evidence.

They do **not** establish that raster-d should own those workers.

## Production state after M5.1–M5.4

Current production already preserves the scheduler-neutral pieces needed by the
raster domain.

### Dependency geometry

`raster.internal.dependency` derives request-bounded raster dependencies as
pure geometry. It contains no scheduling policy.

### Materialization planning

`raster.internal.materialization_plan` maps logical dependency geometry into
resident descriptor space without allocation or worker ownership.

### Caller-owned materialization

`raster.internal.materialization.tryMaterializeRequest` is explicitly
synchronous caller-owned materialization. The caller supplies both the source
capability and destination storage.

### Block resolution

Retained block resolution expresses exact coverage, retained hits/misses and
source materialization without introducing a scheduler abstraction.

### Region-oriented processing

Neighbourhood and convolution operations receive explicit output regions and
caller-owned destinations. They perform no hidden scheduling.

The production architecture therefore separates raster semantics from execution
ownership in the same direction that R0.4e's research vocabulary anticipated.

## Promotion matrix

| R0.4e concept | M5.5 decision | Reason |
| --- | --- | --- |
| stable worker identity | do not promote | scheduler/runtime concern, not raster semantics |
| persistent worker lifecycle | do not promote | consumer/executor ownership concern |
| worker/request identity separation | retain as design principle | prevents request state from being tied to thread lifetime |
| bounded materialization/compute mailboxes | do not promote in raster-d | generic backpressure mechanism, not raster-domain API |
| FIFO ready ordering | do not promote as raster policy | scheduling policy remains caller-owned |
| queue-full/closed states | do not promote | belongs to chosen executor/queue implementation |
| persistent cross-request reuse | do not promote | valid optimization for a caller-owned executor |
| deterministic shutdown/join | retain as requirement for any future owner | necessary if a higher layer owns workers |
| cancellation/failure cleanup | retain as orchestration requirement | request-local state must not poison later work |
| exact synchronous semantic reference | retain | parallel execution must preserve raster semantics |
| finite memory/backpressure | retain as system requirement | implementation mechanism remains higher-layer-owned |
| dependency/materialization geometry | retain/promote only as raster-domain mechanics | independent of scheduler ownership |

## Why no raster-d WorkerPool or Executor

A raster-d-owned persistent pool would introduce policy that the current raster
semantics do not require:

- worker count;
- worker lifetime;
- queue topology and capacity;
- fairness/priority;
- wakeup and blocking primitives;
- cancellation propagation;
- affinity/SMT policy;
- application shutdown integration.

Those choices depend on the embedding application, machine, workload and other
libraries sharing the process.

R0.5 additionally showed that scaling depends strongly on kernel quality,
memory-bandwidth saturation and CPU placement. A fixed raster-d worker policy
would therefore be both architecturally intrusive and performance-fragile.

## Reusable technique boundary

The following R0.4e lessons may be reused by a higher layer without moving the
scheduler into raster-d:

1. keep worker identity independent of request/work identity;
2. reuse workers across requests when the caller's executor benefits;
3. use finite queues/backpressure rather than unbounded admission;
4. make queue close/cancellation explicit;
5. clean request-local retained state before admitting recovery work;
6. preserve deterministic semantic output independent of execution order;
7. join/terminate owned workers explicitly;
8. measure thread placement and memory-system saturation before setting worker
   counts.

These techniques belong naturally in an application scheduler, imagery
pipeline, or a future general-purpose concurrency/container component if a
reusable cross-domain abstraction is independently justified.

## Public API decision

M5.5 adds no public raster-d concurrency API.

In particular, it does not add:

- `Worker`;
- `WorkerPool`;
- `ThreadPool`;
- `Executor`;
- `Task`;
- `Future`;
- `Mailbox`;
- `Queue`;
- worker-count or affinity configuration.

A future public decomposition API is not ruled out, but it must be motivated by
a concrete raster-domain caller need and designed independently of any specific
threading implementation.

## Conclusion

R0.4e is accepted as evidence that persistent worker reuse, bounded
backpressure and recovery can preserve raster semantics.

Its scheduler ownership is **not** promoted.

raster-d retains synchronous, allocation-conscious, region/dependency-oriented
mechanics and leaves execution scheduling to the caller by default. This
satisfies the workspace concurrency contract while preserving the useful
research lessons for higher-level consumers.
