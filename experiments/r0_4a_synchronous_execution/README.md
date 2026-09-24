# R0.4a Synchronous Execution Experiment

Status: experiment contract
Date: 2026-09-24
Tracking issue: #10

Contract baseline:

```text
a29d394 research: define R0.4a synchronous execution contract
```

Authoritative research document:

```text
docs/research/execution.md
```

Nothing in this experiment directory is a stable public API.

## 1. Purpose

R0.4a tests the smallest synchronous raster work-unit lifecycle required by
the execution research contract.

The experiment does not research raster geometry again.

R0.3 already established evidence for:

- output requests;
- legal decompositions;
- dependency expansion;
- logical versus resident coordinates;
- neighbourhood/halo materialization;
- exact whole-versus-decomposed equivalence;
- bounded sequential raster residency.

R0.4a asks a different question:

> Can a scheduler-independent synchronous work-unit lifecycle preserve those
> properties while giving execution order, completion, failure, cancellation
> and residency release precise semantics?

## 2. Research boundary

The experiment introduces no production scheduler.

It does not modify:

```text
source/raster/
```

and does not promote R0.3 research types.

The experiment must not require:

- threads;
- a worker pool;
- futures or promises;
- async I/O;
- work stealing;
- priority scheduling;
- prefetch;
- provider tiles;
- cache blocks;
- GPU execution;
- imagery-specific policy.

If the synchronous experiment requires one of those concepts, the proposed
R0.4a model is too broad or incorrectly factored.

## 3. Existing evidence to preserve

### 3.1 Output request is not a task

The experiment retains the distinction:

```text
output request != scheduler task
```

An output request describes requested logical output.

A work unit is one piece of research execution associated with one processing
region.

The experiment must not make the output-request type scheduler-aware.

### 3.2 Decomposition is not scheduling

The experiment retains:

```text
decomposition != scheduler policy
```

A decomposition defines legal output regions.

The order in which those regions are executed is a separate concern.

### 3.3 Spatial dependency is not execution order

R0.3 dependency semantics determine required logical input geometry.

They do not establish task ordering.

R0.4a must preserve:

```text
spatial dependency
    !=
execution dependency
    !=
execution order
```

### 3.4 Logical and resident coordinates remain separate

A work unit may refer to a non-zero logical region while its resident raster
starts at descriptor-space `(0, 0)`.

No execution state may infer logical placement from resident coordinates.

### 3.5 Work-unit-local bounded residency

The synchronous baseline processes one work unit at a time.

Its local materializations must be released before the next non-empty work
unit begins.

This claim applies only to work-unit-local residency.

It does not decide future semantics for:

- shared materializations;
- caches;
- prefetch;
- concurrent consumers.

## 4. What is new in R0.4a

R0.4a needs new evidence only for:

1. execution-order independence of suitable local operations;
2. work-unit lifecycle;
3. work-unit completion;
4. request completion;
5. materialization failure;
6. operation failure;
7. cancellation between work units;
8. cleanup after every non-success path;
9. distinction between completed work-unit output and completed request output.

## 5. Research vocabulary

The names in this section are conceptual.

They are not proposed production API names.

### 5.1 Work unit

One execution instance associated with one non-empty processing/output region.

Conceptually it has:

```text
processing region
operation/dependency context
execution position/order
```

Required input is derived from operation semantics rather than stored as
scheduler policy.

### 5.2 Work-unit lifecycle

The baseline lifecycle is:

```text
not started
    |
    v
dependency derived
    |
    v
input materialized
    |
    v
operation executing
    |
    v
work-unit completed
    |
    v
result available to research orchestration
    |
    v
work-unit-local residency released
```

Failure may terminate the lifecycle before completion.

Cancellation is observed only before a work unit begins in the initial
baseline.

### 5.3 Work-unit completion

A work unit is complete only when its operation has successfully reached its
ordinary operation-defined completion boundary.

A function merely returning is not sufficient if it reports failure.

A failed work unit is never marked complete.

### 5.4 Request completion

A requested output is complete only when every required non-empty work unit in
its legal decomposition has completed successfully.

Therefore:

```text
some completed work units
    !=
completed request
```

A failed or cancelled request must never be reported as successfully complete.

### 5.5 Completed work-unit output

The experiment may retain or reassemble output from work units that completed
before a later failure or cancellation.

That state is research instrumentation.

It does not define a public partial-result API.

The experiment must distinguish:

```text
completed work-unit output
partial request state
completed requested output
```

## 6. Initial hypotheses

### H1 — order independence

For the selected exact local neighbourhood operation and one fixed legal
decomposition, these execution orders produce byte-identical completed output:

```text
forward
reverse
deterministic permutation
```

The final output must also equal the whole-request reference.

This hypothesis applies only to an operation whose work units have disjoint
output and read-only input dependencies.

It does not establish universal order independence for all raster operations.

### H2 — work-unit-local residency

With synchronous one-at-a-time execution:

```text
active work-unit-local materializations <= one work unit
```

and after each work unit:

```text
current work-unit-local resident bytes == 0
```

before the next non-empty work unit begins.

### H3 — materialization failure

If input materialization for work unit `N` fails:

```text
work units before N
    may already be complete

work unit N
    is not complete

work units after N
    are not started

request
    is not complete

work-unit-local residency at return
    == 0
```

No materialization-failure test may report request success.

### H4 — operation failure

If operation execution for work unit `N` fails after its input has been
materialized:

```text
work units before N
    may already be complete

work unit N
    is not complete

work units after N
    are not started

request
    is not complete

work-unit-local residency at return
    == 0
```

The experiment must verify cleanup independently from failure reporting.

### H5 — cancellation between work units

The baseline observes cancellation immediately before starting each non-empty
work unit.

If cancellation is observed before work unit `N`:

```text
work units before N
    may already be complete

work unit N
    is not started

work units after N
    are not started

request
    is not complete

work-unit-local residency at return
    == 0
```

The baseline does not observe cancellation inside an already executing work
unit.

This is a cancellation-observation rule only.

It does not imply transactional or atomic output semantics.

### H6 — empty request

A valid empty output request:

```text
executes zero work units
materializes zero input
has zero resident bytes
completes successfully
```

This preserves the R0.3 rule:

```text
empty != failure
```

## 7. Principal success fixture

The principal fixture should use:

- deterministic procedural `ubyte` input;
- non-zero logical origin;
- an interior requested output with complete neighbourhood context;
- the exact weighted 3 x 3 R0.3 neighbourhood operation;
- one deliberately irregular legal decomposition.

An irregular decomposition is preferred because it avoids accidentally
testing only one regular traversal pattern.

The same decomposition geometry must be executed in several orders without
changing its membership.

The comparison oracle is:

```text
whole-request reference
    ==
forward decomposed result
    ==
reverse decomposed result
    ==
permuted decomposed result
```

Byte equality is required.

No tolerance is permitted for this exact integer operation.

## 8. Execution-order fixtures

### 8.1 Forward

Execute decomposition members in their stored order.

### 8.2 Reverse

Execute exactly the same members in reverse order.

### 8.3 Deterministic permutation

Execute exactly the same members in a fixed permutation.

The permutation must be deterministic and committed as test data or generated
by a deterministic rule.

Do not use runtime randomness.

### 8.4 What order testing proves

Successful order tests establish only:

> For this operation and this legal decomposition, execution order is not part
> of the semantic result.

They do not prove that every future raster operation may execute in arbitrary
order.

## 9. Lifecycle instrumentation

The experiment should record at least:

```text
non-empty work units considered
work units started
work units completed
materializations started
materializations completed
operation executions started
operation executions completed
current resident raster bytes
peak resident raster bytes
release count
request completed
termination reason
```

Instrumentation is experimental state.

It is not a proposed production telemetry API.

## 10. Completion coverage oracle

To distinguish completed work units from complete request output, the
experiment may maintain a bounded test-only coverage map over the requested
output.

A pixel may be marked complete only when its work unit successfully completes.

The coverage map is an oracle.

It is not a production scheduler structure.

On successful request completion:

```text
all requested output pixels are complete
```

On injected failure or cancellation:

```text
request completed == false
```

even if some prefix of work units has valid completed coverage.

## 11. Failure injection

Failure injection must be deterministic and research-local.

### 11.1 Materialization failure

Select one non-empty work-unit ordinal.

When that ordinal reaches the materialization boundary, inject failure before
a usable resident input is returned.

The test must verify:

- the selected work unit does not execute the operation;
- later work units do not begin;
- the request does not complete;
- work-unit-local residency returns to zero.

### 11.2 Operation failure

Select one non-empty work-unit ordinal.

Materialization succeeds normally.

Failure is then injected at the operation boundary before work-unit completion
is recorded.

The test must verify:

- the selected unit is not marked complete;
- later work units do not begin;
- the request does not complete;
- all local resident input is released.

The experiment must not alter the production raster operation merely to make
failure injection convenient.

A research wrapper or research operation fixture is preferable.

## 12. Cancellation injection

Cancellation is deterministic.

A test specifies the ordinal of the next non-empty work unit before which
cancellation becomes observable.

The executor checks cancellation only at the work-unit boundary.

For the initial baseline:

```text
no work unit is interrupted after it has started
```

Tests should cover cancellation:

- before the first work unit;
- after at least one completed work unit;
- immediately before the final work unit.

All cases must leave work-unit-local residency at zero.

## 13. Cleanup invariant

Every executor return path must satisfy:

```text
current work-unit-local resident bytes == 0
```

including:

- success;
- materialization failure;
- operation failure;
- cancellation;
- empty request.

This is a primary R0.4a invariant.

It must be checked mechanically rather than inferred from lexical scope alone.

## 14. Output-validity experiment

The experiment should deliberately preserve already completed work-unit output
inside its test oracle after a later failure or cancellation.

It must then report separately:

```text
completedCoverage
requestCompleted
terminationReason
```

This permits the research to answer:

- whether prior work-unit completion can remain internally observable;
- whether a failed/cancelled request can be distinguished from success;
- whether a generic transactional request buffer is actually required.

The experiment must not expose partial output through `source/raster/`.

## 15. Empty-output experiment

The empty-output case must not be forced through a fake zero-sized work unit.

The expected lifecycle is:

```text
validate empty request
    ->
zero executable work units
    ->
zero materialization
    ->
zero operation calls
    ->
successful request completion
```

This keeps empty geometry distinct from failure.

## 16. Reuse of R0.3 evidence

R0.4a must not edit R0.3 merely to make the new experiment easier.

The existing directory:

```text
experiments/r0_3_regions_streaming/
```

remains prior research evidence.

Before implementation, choose the smallest maintainable way to consume the
required R0.3 semantics.

Acceptable implementation directions to evaluate include:

1. compile selected existing research modules as sibling experimental inputs;
2. use a narrow R0.4a adapter around selected existing research functions;
3. reproduce only trivial fixture construction where direct reuse would create
   worse experiment coupling.

Algorithms such as dependency expansion or decomposition validation must not
be silently copied into competing implementations.

Any deliberate duplication must be called out and justified.

### 16.1 Selected reuse strategy

R0.4a will consume selected R0.3 research modules directly and unchanged.

The R0.4a DUB experiment should compile the required sibling research sources
from:

```text
experiments/r0_3_regions_streaming/
```

No R0.3 source file is modified merely to make R0.4a easier.

The selected reusable primitives are:

```text
region_algebra.d
dependency.d
decomposition_oracle.d
procedural_source.d
neighbourhood_kernel.d
```

Their roles remain the same as in R0.3:

```text
region_algebra
    -> checked research geometry

dependency
    -> request-bounded dependency expansion

decomposition_oracle
    -> bounded exact decomposition validation

procedural_source
    -> deterministic logical-to-resident materialization

neighbourhood_kernel
    -> exact weighted 3 x 3 pixel operation
```

R0.4a must call those existing implementations rather than copy their
algorithms into new competing helpers.

The R0.3 module:

```text
neighbourhood_task_execution.d
```

has a different role.

Its:

```text
executeNeighbourhoodTask()
```

already composes dependency derivation, materialization and neighbourhood
execution inside one proven E3.3 task path.

That makes it useful as an independent correctness oracle, but unsuitable as
the execution path under test in R0.4a.

Using it as the R0.4a executor would hide exactly the lifecycle boundaries that
R0.4a must observe:

```text
dependency derived
materialization started/completed
operation started/completed
work-unit completion
residency release
```

Therefore R0.4a may compile and call:

```text
neighbourhood_task_execution.d
```

only for success-path result comparison.

It must not use `executeNeighbourhoodTask()` as the work-unit lifecycle being
measured.

The R0.4a execution path instead composes the lower-level R0.3 primitives
explicitly so that failure injection, cancellation boundaries and residency
accounting remain observable.

This necessarily introduces some R0.4a-specific orchestration for:

```text
logical-output to resident-input mapping
neighbour sample access
work-unit result construction
```

That orchestration is permitted because it is the subject of the R0.4a
experiment.

The neighbourhood arithmetic itself remains delegated to the existing:

```text
weightedNeighbourhood3x3()
```

kernel.

To prevent an orchestration mistake from being mistaken for new execution
semantics, every successful R0.4a work unit should be comparable against the
existing R0.3 `executeNeighbourhoodTask()` result for the same logical region.

### 16.2 What is deliberately not reused

R0.4a should not execute through:

```text
neighbourhood_streaming.d
```

because that module already contains an E3.3 sequential decomposition loop,
reassembly and residency accounting.

Reusing that loop would make the R0.4a lifecycle circular: the experiment
would be measuring the old orchestration instead of the new execution
contract.

Likewise:

```text
neighbourhood_whole_reference.d
```

is not required for the initial R0.4a implementation.

The existing per-task E3.3 oracle is sufficient to validate the R0.4a
operation result, while whole-versus-decomposed request equivalence can be
established by running the same R0.4a lifecycle over a one-member
decomposition and over the multi-member decomposition.

This keeps the dependency graph smaller and avoids pulling the complete E3.3
streaming harness into the new experiment.

### 16.3 Dependency direction

The research dependency is strictly:

```text
R0.4a experiment
    ->
selected immutable R0.3 research modules
    ->
production raster-d API
```

R0.3 must never import R0.4a.

Production `source/raster/` must never import either experiment.

This reuse decision is research organization only and does not establish a
stable library boundary between experiment directories.

## 17. Initial implementation shape

The expected experiment should remain small.

A likely shape is:

```text
experiments/r0_4a_synchronous_execution/
    README.md
    dub.sdl
    synchronous_execution.d
```

Additional modules should be introduced only if the implementation proves
that one file obscures independent concerns.

The first implementation must not create a reusable scheduler framework.

## 18. Compiler verification

The experiment must pass with both supported current compiler families:

```text
DMD
LDC
```

Compiler-floor verification may follow once the experiment contract and
implementation stabilize.

R0.4a correctness must not depend on compiler-specific scheduling behavior.

## 19. Required result matrix

The completion report should include at least:

| Case | Expected request result | Completed work | Final local residency |
| --- | --- | --- | --- |
| whole reference | success | all | 0 |
| forward decomposition | success | all | 0 |
| reverse decomposition | success | all | 0 |
| deterministic permutation | success | all | 0 |
| materialization failure | failure | prefix only | 0 |
| operation failure | failure | prefix only | 0 |
| cancel before first | cancelled | none | 0 |
| cancel after prefix | cancelled | prefix only | 0 |
| cancel before final | cancelled | all prior units | 0 |
| empty request | success | none required | 0 |

The exact numeric fixture results must be recorded after implementation rather
than invented in advance.

## 20. Success gate

R0.4a experimental evidence is sufficient only if all of the following hold:

1. whole and decomposed successful execution are exactly equivalent;
2. forward, reverse and deterministic-permutation order are exactly
   equivalent for the selected local operation;
3. successful work units have an explicit completion boundary;
4. failed work units are never reported complete;
5. failed or cancelled requests are never reported complete;
6. materialization failure stops later work;
7. operation failure stops later work;
8. cancellation is observable between work units without modifying RasterView;
9. every return path releases work-unit-local residency;
10. empty output completes successfully without fake work;
11. non-zero logical origins remain separate from resident coordinates;
12. no production scheduler/cache/provider/image policy is introduced;
13. DMD and LDC produce the same deterministic correctness result.

## 21. Decision after the experiment

If the success gate passes, R0.4a may conclude that a synchronous work-unit
lifecycle is a sufficient semantic reference for later scheduler research.

That conclusion would justify proceeding to bounded parallel execution
research.

It would not by itself justify:

- a public scheduler API;
- a public WorkUnit type;
- a task graph;
- a cancellation-token API;
- an execution framework in `source/raster/`.

If the experiment fails because scheduler-specific concepts are required for
correctness, the research contract must be revisited before further
implementation.
