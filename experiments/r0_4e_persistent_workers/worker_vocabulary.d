module worker_vocabulary;


/++
    R0.4e research-local persistent raster worker role.

    These names describe the first candidate staged worker set only.

    They are not a production thread-pool API.
+/
enum PersistentWorkerRole : ubyte
{
    materialization,
    compute
}


/++
    R0.4e research-local worker lifetime vocabulary.

    R0.4e-0 names the states only.

    Transition behaviour belongs to R0.4e-1.
+/
enum PersistentWorkerLifecycle : ubyte
{
    notStarted,
    running,
    waiting,
    shutdownObserved,
    joined
}


/++
    Stable worker identity used only for deterministic experiment evidence.

    Worker identity is intentionally separate from request and work-unit
    identity.
+/
struct StableWorkerIdentity
{
    size_t stableWorkerId;
    PersistentWorkerRole role;
}


/++
    Stable request identity used only to make cross-request reuse explicit.

    This is not a production request handle.
+/
struct StableRequestIdentity
{
    size_t stableRequestId;
}


/++
    R0.4e research-local stage-queue names.

    Queue implementation belongs to R0.4e-2.
+/
enum StageQueueKind : ubyte
{
    materialization,
    compute
}


/++
    Explicit finite queue-capacity vocabulary for the first persistent-worker
    candidate.

    R0.4e-0 defines no queue and no blocking semantics.
+/
struct StageQueueLimits
{
    size_t materializationQueueCapacity;
    size_t computeQueueCapacity;
}


/*
 * Vocabulary identity and lifetime separation are explicit.
 */
unittest
{
    static assert(
        PersistentWorkerRole.materialization
        != PersistentWorkerRole.compute
    );


    static assert(
        PersistentWorkerLifecycle.notStarted
        != PersistentWorkerLifecycle.running
    );

    static assert(
        PersistentWorkerLifecycle.running
        != PersistentWorkerLifecycle.waiting
    );

    static assert(
        PersistentWorkerLifecycle.waiting
        != PersistentWorkerLifecycle.shutdownObserved
    );

    static assert(
        PersistentWorkerLifecycle.shutdownObserved
        != PersistentWorkerLifecycle.joined
    );


    static assert(
        StageQueueKind.materialization
        != StageQueueKind.compute
    );


    const materializationWorker =
        StableWorkerIdentity(
            10,
            PersistentWorkerRole.materialization
        );

    const computeWorker =
        StableWorkerIdentity(
            11,
            PersistentWorkerRole.compute
        );


    const firstRequest =
        StableRequestIdentity(100);

    const secondRequest =
        StableRequestIdentity(101);


    const limits =
        StageQueueLimits(
            2,
            3
        );


    assert(
        materializationWorker.stableWorkerId
        != computeWorker.stableWorkerId
    );

    assert(
        materializationWorker.role
        != computeWorker.role
    );


    assert(
        firstRequest.stableRequestId
        != secondRequest.stableRequestId
    );


    assert(limits.materializationQueueCapacity == 2);
    assert(limits.computeQueueCapacity == 3);
}
