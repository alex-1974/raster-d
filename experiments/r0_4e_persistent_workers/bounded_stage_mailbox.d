module bounded_stage_mailbox;

import core.sync.barrier :
    Barrier;

import core.sync.condition :
    Condition;

import core.sync.mutex :
    Mutex;

import core.thread :
    Thread;

import worker_vocabulary :
    StageQueueKind;


/++
    Minimal research payload carried by one stage mailbox.

    This is not a public task type.
+/
struct QueuedStageWork
{
    size_t stableWorkUnitId;
    size_t readyOrdinal;
}


/++
    Non-blocking producer result.
+/
enum StageMailboxPushError : ubyte
{
    none,
    full,
    closed
}


/++
    Blocking consumer result category.
+/
enum StageMailboxPopKind : ubyte
{
    item,
    closed
}


struct StageMailboxPopResult
{
    StageMailboxPopKind kind =
        StageMailboxPopKind.closed;

    QueuedStageWork work;


    @property
    bool hasItem() const
    @safe
    pure
    nothrow
    @nogc
    {
        return kind
            == StageMailboxPopKind.item;
    }
}


/++
    Snapshot of bounded-mailbox evidence.

    All fields are copied while the mailbox mutex is held.
+/
struct StageMailboxSnapshot
{
    StageQueueKind kind;

    size_t capacity;
    size_t currentCount;
    size_t peakCount;

    size_t acceptedPushes;
    size_t rejectedFullPushes;
    size_t rejectedClosedPushes;

    size_t pops;

    size_t waitEntries;
    size_t wakeReturns;

    bool closed;
}


/++
    R0.4e-2 bounded stage mailbox.

    Producer admission is non-blocking.

    Consumer wait is condition-variable based.

    Close rejects later pushes, preserves already queued FIFO work for draining,
    wakes blocked consumers and eventually yields StageMailboxPopKind.closed
    once the queue is empty.

    This is disposable research machinery, not a production queue API.
+/
class BoundedStageMailbox
{
    private StageQueueKind kind_;
    private size_t capacity_;


    private Mutex mutex_;
    private Condition notEmpty_;


    private QueuedStageWork[] slots_;

    private size_t head_;
    private size_t count_;


    private size_t peakCount_;

    private size_t acceptedPushes_;
    private size_t rejectedFullPushes_;
    private size_t rejectedClosedPushes_;

    private size_t pops_;

    private size_t waitEntries_;
    private size_t wakeReturns_;

    private bool closed_;


    this(
        StageQueueKind kind,
        size_t capacity
    )
    {
        assert(capacity != 0);


        kind_ =
            kind;

        capacity_ =
            capacity;


        mutex_ =
            new Mutex;

        notEmpty_ =
            new Condition(
                mutex_
            );


        slots_ =
            new QueuedStageWork[capacity];
    }


    /++
        Attempts one producer admission without blocking.

        Full and closed are ordinary deterministic research outcomes.
    +/
    StageMailboxPushError tryPush(
        QueuedStageWork work
    )
    {
        synchronized (mutex_)
        {
            if (closed_)
            {
                ++rejectedClosedPushes_;

                return StageMailboxPushError.closed;
            }


            if (count_ == capacity_)
            {
                ++rejectedFullPushes_;

                return StageMailboxPushError.full;
            }


            size_t tail;


            if (
                count_
                >= capacity_ - head_
            )
            {
                tail =
                    count_
                    - (capacity_ - head_);
            }
            else
            {
                tail =
                    head_
                    + count_;
            }


            assert(tail < capacity_);


            slots_[tail] =
                work;


            ++count_;
            ++acceptedPushes_;


            if (count_ > peakCount_)
            {
                peakCount_ =
                    count_;
            }


            notEmpty_.notify();


            return StageMailboxPushError.none;
        }
    }


    /++
        Waits until one FIFO item is available or the closed mailbox has been
        completely drained.

        waitObservationGate is an optional research-only synchronization hook.

        On the first actual wait performed by this invocation, the worker joins
        that barrier while still holding the mailbox mutex. After the barrier,
        Condition.wait atomically releases the mutex and blocks. A coordinator
        that returns from the same barrier can therefore trigger push/close
        without a lost-notification race.

        The hook is not queue semantics and is not a proposed production API.
    +/
    StageMailboxPopResult waitPop(
        Barrier waitObservationGate = null
    )
    {
        synchronized (mutex_)
        {
            bool observationPublished;


            while (
                count_ == 0
                && !closed_
            )
            {
                ++waitEntries_;


                if (
                    !observationPublished
                    && waitObservationGate !is null
                )
                {
                    observationPublished =
                        true;

                    waitObservationGate.wait();
                }


                notEmpty_.wait();

                ++wakeReturns_;
            }


            StageMailboxPopResult result;


            if (count_ != 0)
            {
                result.kind =
                    StageMailboxPopKind.item;

                result.work =
                    slots_[head_];


                ++head_;

                if (head_ == capacity_)
                {
                    head_ =
                        0;
                }


                --count_;
                ++pops_;


                return result;
            }


            assert(closed_);


            result.kind =
                StageMailboxPopKind.closed;

            return result;
        }
    }


    /++
        Closes producer admission and wakes all blocked consumers.

        Existing queued items remain drainable.

        Returns true only for the first close transition.
    +/
    bool close()
    {
        synchronized (mutex_)
        {
            if (closed_)
            {
                return false;
            }


            closed_ =
                true;


            notEmpty_.notifyAll();


            return true;
        }
    }


    /++
        Returns one synchronized evidence snapshot.
    +/
    StageMailboxSnapshot snapshot()
    {
        synchronized (mutex_)
        {
            return StageMailboxSnapshot(
                kind_,
                capacity_,
                count_,
                peakCount_,
                acceptedPushes_,
                rejectedFullPushes_,
                rejectedClosedPushes_,
                pops_,
                waitEntries_,
                wakeReturns_,
                closed_
            );
        }
    }
}


/*
 * One consumer thread used only to prove deterministic empty-queue blocking,
 * item wakeup and close wakeup.
 */
private class BlockingMailboxConsumer
{
    BoundedStageMailbox mailbox;

    Barrier waitObservationGate;
    Barrier firstResultGate;


    StageMailboxPopResult first;
    StageMailboxPopResult second;


    this(
        BoundedStageMailbox mailbox,
        Barrier waitObservationGate,
        Barrier firstResultGate
    )
    {
        this.mailbox =
            mailbox;

        this.waitObservationGate =
            waitObservationGate;

        this.firstResultGate =
            firstResultGate;
    }


    void run()
    {
        first =
            mailbox.waitPop(
                waitObservationGate
            );


        /*
         * Publish the first result before entering the second blocking pop.
         */
        firstResultGate.wait();


        second =
            mailbox.waitPop(
                waitObservationGate
            );
    }
}


/*
 * Capacity/full/FIFO/drain behaviour for the materialization mailbox.
 */
unittest
{
    auto mailbox =
        new BoundedStageMailbox(
            StageQueueKind.materialization,
            2
        );


    assert(
        mailbox.tryPush(
            QueuedStageWork(
                10,
                0
            )
        )
        == StageMailboxPushError.none
    );


    assert(
        mailbox.tryPush(
            QueuedStageWork(
                20,
                1
            )
        )
        == StageMailboxPushError.none
    );


    auto fullSnapshot =
        mailbox.snapshot();


    assert(fullSnapshot.capacity == 2);
    assert(fullSnapshot.currentCount == 2);
    assert(fullSnapshot.peakCount == 2);


    /*
     * The third admission is rejected without changing queue occupancy.
     */
    assert(
        mailbox.tryPush(
            QueuedStageWork(
                30,
                2
            )
        )
        == StageMailboxPushError.full
    );


    auto afterFull =
        mailbox.snapshot();


    assert(afterFull.currentCount == 2);
    assert(afterFull.peakCount == 2);
    assert(afterFull.acceptedPushes == 2);
    assert(afterFull.rejectedFullPushes == 1);


    auto first =
        mailbox.waitPop();


    assert(first.hasItem);
    assert(first.work.stableWorkUnitId == 10);
    assert(first.work.readyOrdinal == 0);


    /*
     * Once one FIFO item leaves, producer admission resumes.
     */
    assert(
        mailbox.tryPush(
            QueuedStageWork(
                30,
                2
            )
        )
        == StageMailboxPushError.none
    );


    auto second =
        mailbox.waitPop();

    auto third =
        mailbox.waitPop();


    assert(second.hasItem);
    assert(third.hasItem);

    assert(second.work.stableWorkUnitId == 20);
    assert(second.work.readyOrdinal == 1);

    assert(third.work.stableWorkUnitId == 30);
    assert(third.work.readyOrdinal == 2);


    assert(mailbox.close());
    assert(!mailbox.close());


    /*
     * Closed producer admission is permanent.
     */
    assert(
        mailbox.tryPush(
            QueuedStageWork(
                40,
                3
            )
        )
        == StageMailboxPushError.closed
    );


    auto closed =
        mailbox.waitPop();


    assert(
        closed.kind
        == StageMailboxPopKind.closed
    );


    auto finalSnapshot =
        mailbox.snapshot();


    assert(
        finalSnapshot.kind
        == StageQueueKind.materialization
    );

    assert(finalSnapshot.capacity == 2);
    assert(finalSnapshot.currentCount == 0);
    assert(finalSnapshot.peakCount == 2);

    assert(finalSnapshot.acceptedPushes == 3);
    assert(finalSnapshot.rejectedFullPushes == 1);
    assert(finalSnapshot.rejectedClosedPushes == 1);

    assert(finalSnapshot.pops == 3);
    assert(finalSnapshot.closed);
}


/*
 * Deterministic blocking/wakeup/close behaviour for the compute mailbox.
 */
unittest
{
    auto mailbox =
        new BoundedStageMailbox(
            StageQueueKind.compute,
            1
        );


    auto waitObservationGate =
        new Barrier(2);

    auto firstResultGate =
        new Barrier(2);


    auto consumer =
        new BlockingMailboxConsumer(
            mailbox,
            waitObservationGate,
            firstResultGate
        );


    auto thread =
        new Thread(
            &consumer.run
        );


    thread.start();


    /*
     * The consumer reaches the first empty/open wait boundary while holding
     * the mailbox mutex.
     */
    waitObservationGate.wait();


    /*
     * tryPush cannot acquire the mailbox mutex until waitPop executes
     * Condition.wait and atomically releases that mutex. The subsequent notify
     * therefore cannot be lost.
     */
    assert(
        mailbox.tryPush(
            QueuedStageWork(
                55,
                0
            )
        )
        == StageMailboxPushError.none
    );


    /*
     * The consumer confirms one item result before entering its second pop.
     */
    firstResultGate.wait();


    assert(consumer.first.hasItem);
    assert(consumer.first.work.stableWorkUnitId == 55);
    assert(consumer.first.work.readyOrdinal == 0);


    /*
     * The same consumer reaches a second empty/open wait boundary.
     */
    waitObservationGate.wait();


    /*
     * Close wakes the blocked consumer. With no retained items left, the
     * second result is closed.
     */
    assert(mailbox.close());


    thread.join();


    assert(
        consumer.second.kind
        == StageMailboxPopKind.closed
    );


    auto finalSnapshot =
        mailbox.snapshot();


    assert(
        finalSnapshot.kind
        == StageQueueKind.compute
    );

    assert(finalSnapshot.capacity == 1);
    assert(finalSnapshot.currentCount == 0);
    assert(finalSnapshot.peakCount == 1);

    assert(finalSnapshot.acceptedPushes == 1);
    assert(finalSnapshot.pops == 1);

    /*
     * At least one real condition wait occurred for each blocking pop.
     *
     * Spurious wakeups, if any, may increase these counters but do not affect
     * correctness because waitPop always rechecks its predicate.
     */
    assert(finalSnapshot.waitEntries >= 2);
    assert(finalSnapshot.wakeReturns >= 2);

    assert(finalSnapshot.closed);
}
