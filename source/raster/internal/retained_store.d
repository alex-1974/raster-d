module raster.internal.retained_store;

import std.algorithm.mutation :
    move;

import raster.backing :
    RasterLease;


/++
    Result of one package-internal retained-store insertion attempt.
+/
package(raster)
enum RetainedStoreInsertResult : ubyte
{
    inserted,
    duplicateKey,
    invalidRetainedValue,
    retainedByteBudgetExceeded,
    entryCapacityExceeded
}


/++
    Fixed-capacity retained raster store over caller-owned semantic keys.

    Identity semantics are supplied entirely by Key, hashKey and sameKey.

    The store intentionally defines no replacement/eviction policy.
+/
package(raster)
struct RetainedRasterStore(
    T,
    Key,
    size_t EntryCapacity,
    alias hashKey,
    alias sameKey
)
{
    static assert(
        EntryCapacity > 0,
        "RetainedRasterStore requires at least one entry slot."
    );

private:
    struct Entry
    {
        bool occupied;

        Key key;

        size_t physicalBytes;

        RasterLease!T lease;
    }

    Entry[EntryCapacity] entries_;

    size_t retainedByteLimit_;

    size_t retainedBytes_;

    size_t entryCount_;


    /++
        Returns the first byte address of one retained-store slot.
    +/
    size_t slotStart(
        ref const Key key
    )
    @safe
    nothrow
    @nogc
    {
        return
            hashKey(key)
            % EntryCapacity;
    }


public:
    package(raster)
    this(size_t retainedByteLimit)
    @safe
    pure
    nothrow
    @nogc
    {
        retainedByteLimit_ =
            retainedByteLimit;
    }


    package(raster)
    @property
    /++
        Returns the configured retained-store byte budget.
    +/
    size_t retainedByteLimit() const
    @safe
    pure
    nothrow
    @nogc
    {
        return retainedByteLimit_;
    }


    package(raster)
    @property
    /++
        Returns bytes currently retained by populated store entries.
    +/
    size_t retainedBytes() const
    @safe
    pure
    nothrow
    @nogc
    {
        return retainedBytes_;
    }


    package(raster)
    @property
    /++
        Returns the number of populated retained-store entries.
    +/
    size_t entryCount() const
    @safe
    pure
    nothrow
    @nogc
    {
        return entryCount_;
    }


    package(raster)
    @property
    /++
        Returns the fixed retained-store entry capacity.
    +/
    size_t entryCapacity() const
    @safe
    pure
    nothrow
    @nogc
    {
        return EntryCapacity;
    }


    /++
        Attempts to acquire one independently retained lease copy.

        False means key miss.
    +/
    package(raster)
    bool tryAcquire(
        ref const Key key,
        out RasterLease!T lease
    )
    @trusted
    nothrow
    @nogc
    {
        lease =
            RasterLease!T.init;

        const start =
            slotStart(key);

        foreach (probe; 0 .. EntryCapacity)
        {
            const index =
                (start + probe)
                % EntryCapacity;

            if (!entries_[index].occupied)
            {
                return false;
            }

            if (
                sameKey(
                    entries_[index].key,
                    key
                )
            )
            {
                lease =
                    entries_[index].lease;

                return true;
            }
        }

        return false;
    }


    /++
        Moves one retained value into the store.

        Rejected insertion leaves both store state and the input lease
        unchanged.
    +/
    package(raster)
    RetainedStoreInsertResult insertOwned(
        Key key,
        ref RasterLease!T lease
    )
    @trusted
    nothrow
    @nogc
    {
        size_t physicalBytes;

        if (
            !lease.tryPhysicalResourceBytes(
                physicalBytes
            )
        )
        {
            return
                RetainedStoreInsertResult
                    .invalidRetainedValue;
        }

        if (
            physicalBytes
            > retainedByteLimit_ - retainedBytes_
        )
        {
            return
                RetainedStoreInsertResult
                    .retainedByteBudgetExceeded;
        }

        const start =
            slotStart(key);

        size_t freeIndex =
            EntryCapacity;

        foreach (probe; 0 .. EntryCapacity)
        {
            const index =
                (start + probe)
                % EntryCapacity;

            if (!entries_[index].occupied)
            {
                freeIndex =
                    index;

                break;
            }

            if (
                sameKey(
                    entries_[index].key,
                    key
                )
            )
            {
                return
                    RetainedStoreInsertResult
                        .duplicateKey;
            }
        }

        if (freeIndex == EntryCapacity)
        {
            return
                RetainedStoreInsertResult
                    .entryCapacityExceeded;
        }

        entries_[freeIndex].key =
            move(key);

        entries_[freeIndex].physicalBytes =
            physicalBytes;

        entries_[freeIndex].lease =
            move(lease);

        entries_[freeIndex].occupied =
            true;

        retainedBytes_ +=
            physicalBytes;

        ++entryCount_;

        assert(
            retainedBytes_
            <= retainedByteLimit_
        );

        assert(
            entryCount_
            <= EntryCapacity
        );

        return
            RetainedStoreInsertResult
                .inserted;
    }


    /++
        Releases all store-owned retained values and resets store accounting.

        Independent RasterLease copies acquired earlier remain valid.
    +/
    package(raster)
    void clear()
    @trusted
    nothrow
    @nogc
    {
        foreach (ref entry; entries_)
        {
            if (!entry.occupied)
            {
                continue;
            }

            entry.lease =
                RasterLease!T.init;

            entry.key =
                Key.init;

            entry.physicalBytes =
                0;

            entry.occupied =
                false;
        }

        retainedBytes_ =
            0;

        entryCount_ =
            0;
    }
}


version (unittest)
{

import core.stdc.stdlib :
    malloc;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster;


private
struct OpaqueKey
{
    ulong high;

    ulong low;
}


private
size_t opaqueHash(
    ref const OpaqueKey key
)
@safe
pure
nothrow
@nogc
{
    return
        cast(size_t)(
            key.high
            ^ (
                key.low
                * 0x9E3779B97F4A7C15UL
            )
        );
}


private
bool opaqueEqual(
    ref const OpaqueKey lhs,
    ref const OpaqueKey rhs
)
@safe
pure
nothrow
@nogc
{
    return lhs == rhs;
}


private
struct CollisionKey
{
    size_t id;
}


private
size_t collisionHash(
    ref const CollisionKey key
)
@safe
pure
nothrow
@nogc
{
    return 1;
}


private
bool collisionEqual(
    ref const CollisionKey lhs,
    ref const CollisionKey rhs
)
@safe
pure
nothrow
@nogc
{
    return lhs == rhs;
}


private
struct CompositeKey
{
    size_t source;

    size_t generation;

    Region2D region;

    size_t schema;
}


private
size_t compositeHash(
    ref const CompositeKey key
)
@safe
pure
nothrow
@nogc
{
    size_t state =
        key.source;

    state ^=
        key.generation
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.x
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.y
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.width
        + (state << 6)
        + (state >> 2);

    state ^=
        key.region.height
        + (state << 6)
        + (state >> 2);

    state ^=
        key.schema
        + (state << 6)
        + (state >> 2);

    return state;
}


private
bool compositeEqual(
    ref const CompositeKey lhs,
    ref const CompositeKey rhs
)
@safe
pure
nothrow
@nogc
{
    return lhs == rhs;
}


private
bool makeSinglePlaneLease(
    Region2D logicalRegion,
    size_t rowPaddingBytes,
    out RasterLease!ubyte lease,
    out size_t physicalBytes
)
@system
{
    lease =
        RasterLease!ubyte.init;

    physicalBytes =
        0;

    if (
        logicalRegion.width
        > size_t.max - rowPaddingBytes
    )
    {
        return false;
    }

    const rowStride =
        logicalRegion.width
        + rowPaddingBytes;

    if (
        logicalRegion.height != 0
        && rowStride
            > size_t.max / logicalRegion.height
    )
    {
        return false;
    }

    physicalBytes =
        rowStride
        * logicalRegion.height;

    /*
     * malloc(0) is implementation-defined, so keep zero-byte fixtures out of
     * this helper.
     */
    if (physicalBytes == 0)
    {
        return false;
    }

    auto memory =
        cast(ubyte*) malloc(
            physicalBytes
        );

    if (memory is null)
    {
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            memory[
                y * rowStride + x
            ] =
                cast(ubyte)(
                    cast(ubyte) (
                        logicalRegion.x + x
                    )
                    ^ cast(ubyte) (
                        logicalRegion.y + y
                    )
                );
        }
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            physicalBytes,
            resource
        )
    )
    {
        return false;
    }

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) rowStride,
                    1
                )
            ],
            Region2D(
                0,
                0,
                logicalRegion.width,
                logicalRegion.height
            ),
            lease
        );

    if (!result.ok)
    {
        return false;
    }

    return true;
}


private
bool makeInterleavedLease(
    Region2D logicalRegion,
    size_t rowPaddingBytes,
    out RasterLease!ubyte lease,
    out size_t physicalBytes
)
@system
{
    lease =
        RasterLease!ubyte.init;

    physicalBytes =
        0;

    if (
        logicalRegion.width
        > (size_t.max - rowPaddingBytes) / 2
    )
    {
        return false;
    }

    const rowStride =
        logicalRegion.width * 2
        + rowPaddingBytes;

    if (
        logicalRegion.height != 0
        && rowStride
            > size_t.max / logicalRegion.height
    )
    {
        return false;
    }

    physicalBytes =
        rowStride
        * logicalRegion.height;

    if (physicalBytes == 0)
    {
        return false;
    }

    auto memory =
        cast(ubyte*) malloc(
            physicalBytes
        );

    if (memory is null)
    {
        return false;
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            physicalBytes,
            resource
        )
    )
    {
        return false;
    }

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) rowStride,
                    2
                ),
                PlaneByteLayout(
                    1,
                    cast(ptrdiff_t) rowStride,
                    2
                )
            ],
            Region2D(
                0,
                0,
                logicalRegion.width,
                logicalRegion.height
            ),
            lease
        );

    return result.ok;
}


private
bool leaseReadable(
    ref RasterLease!ubyte lease,
    Region2D region
)
@safe
{
    auto view =
        lease.view();

    return
        view.width == region.width
        && view.height == region.height;
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            4,
            opaqueHash,
            opaqueEqual
        );

    Store store =
        Store(1_024);

    const key =
        OpaqueKey(
            0x1122,
            0x3344
        );

    RasterLease!ubyte lease;
    size_t physicalBytes;

    const region =
        Region2D(
            100,
            200,
            8,
            8
        );

    assert(
        makeSinglePlaneLease(
            region,
            0,
            lease,
            physicalBytes
        )
    );

    assert(physicalBytes == 64);

    assert(
        store.insertOwned(
            key,
            lease
        )
        == RetainedStoreInsertResult
            .inserted
    );

    assert(store.entryCount == 1);
    assert(store.retainedBytes == 64);

    RasterLease!ubyte acquired;

    assert(
        store.tryAcquire(
            key,
            acquired
        )
    );

    assert(
        leaseReadable(
            acquired,
            region
        )
    );

    const missingKey =
        OpaqueKey(
            0x1122,
            0x3345
        );

    RasterLease!ubyte missing;

    assert(
        !store.tryAcquire(
            missingKey,
            missing
        )
    );
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            CollisionKey,
            4,
            collisionHash,
            collisionEqual
        );

    Store store =
        Store(1_024);

    foreach (id; 0 .. 3)
    {
        const region =
            Region2D(
                10 + id * 10,
                20,
                4,
                4
            );

        RasterLease!ubyte lease;
        size_t bytes;

        assert(
            makeSinglePlaneLease(
                region,
                0,
                lease,
                bytes
            )
        );

        const key =
            CollisionKey(id);

        assert(
            store.insertOwned(
                key,
                lease
            )
            == RetainedStoreInsertResult
                .inserted
        );
    }

    foreach (id; 0 .. 3)
    {
        const key =
            CollisionKey(id);

        RasterLease!ubyte acquired;

        assert(
            store.tryAcquire(
                key,
                acquired
            )
        );
    }
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            2,
            opaqueHash,
            opaqueEqual
        );

    Store store =
        Store(128);

    const region =
        Region2D(
            0,
            0,
            8,
            8
        );

    RasterLease!ubyte first;
    size_t firstBytes;

    assert(
        makeSinglePlaneLease(
            region,
            0,
            first,
            firstBytes
        )
    );

    const firstKey =
        OpaqueKey(1, 1);

    assert(
        store.insertOwned(
            firstKey,
            first
        )
        == RetainedStoreInsertResult
            .inserted
    );

    assert(store.retainedBytes == 64);

    RasterLease!ubyte duplicate;
    size_t duplicateBytes;

    assert(
        makeSinglePlaneLease(
            region,
            0,
            duplicate,
            duplicateBytes
        )
    );

    const beforeBytes =
        store.retainedBytes;

    const beforeCount =
        store.entryCount;

    assert(
        store.insertOwned(
            firstKey,
            duplicate
        )
        == RetainedStoreInsertResult
            .duplicateKey
    );

    assert(store.retainedBytes == beforeBytes);
    assert(store.entryCount == beforeCount);

    size_t stillOwnedBytes;

    assert(
        duplicate.tryPhysicalResourceBytes(
            stillOwnedBytes
        )
    );

    assert(stillOwnedBytes == duplicateBytes);
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            4,
            opaqueHash,
            opaqueEqual
        );

    const region =
        Region2D(
            0,
            0,
            8,
            8
        );

    RasterLease!ubyte lease;
    size_t bytes;

    assert(
        makeSinglePlaneLease(
            region,
            0,
            lease,
            bytes
        )
    );

    assert(bytes == 64);

    Store exact =
        Store(64);

    const key =
        OpaqueKey(1, 2);

    assert(
        exact.insertOwned(
            key,
            lease
        )
        == RetainedStoreInsertResult
            .inserted
    );

    assert(exact.retainedBytes == 64);

    RasterLease!ubyte tooLarge;
    size_t tooLargeBytes;

    assert(
        makeSinglePlaneLease(
            region,
            0,
            tooLarge,
            tooLargeBytes
        )
    );

    Store tooSmall =
        Store(63);

    const tooLargeKey =
        OpaqueKey(2, 3);

    assert(
        tooSmall.insertOwned(
            tooLargeKey,
            tooLarge
        )
        == RetainedStoreInsertResult
            .retainedByteBudgetExceeded
    );

    assert(tooSmall.retainedBytes == 0);
    assert(tooSmall.entryCount == 0);
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            4,
            opaqueHash,
            opaqueEqual
        );

    Store store =
        Store(128);

    foreach (id; 0 .. 2)
    {
        const region =
            Region2D(
                id * 8,
                0,
                8,
                8
            );

        RasterLease!ubyte lease;
        size_t bytes;

        assert(
            makeSinglePlaneLease(
                region,
                0,
                lease,
                bytes
            )
        );

        const key =
            OpaqueKey(
                id,
                id + 10
            );

        assert(
            store.insertOwned(
                key,
                lease
            )
            == RetainedStoreInsertResult
                .inserted
        );
    }

    assert(store.retainedBytes == 128);
    assert(store.entryCount == 2);

    RasterLease!ubyte third;
    size_t thirdBytes;

    assert(
        makeSinglePlaneLease(
            Region2D(
                16,
                0,
                8,
                8
            ),
            0,
            third,
            thirdBytes
        )
    );

    const thirdKey =
        OpaqueKey(
            3,
            13
        );

    assert(
        store.insertOwned(
            thirdKey,
            third
        )
        == RetainedStoreInsertResult
            .retainedByteBudgetExceeded
    );

    assert(store.retainedBytes == 128);
    assert(store.entryCount == 2);
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            2,
            opaqueHash,
            opaqueEqual
        );

    Store store =
        Store(1_024);

    foreach (id; 0 .. 2)
    {
        RasterLease!ubyte lease;
        size_t bytes;

        assert(
            makeSinglePlaneLease(
                Region2D(
                    id * 4,
                    0,
                    4,
                    4
                ),
                0,
                lease,
                bytes
            )
        );

        const key =
            OpaqueKey(
                id,
                0
            );

        assert(
            store.insertOwned(
                key,
                lease
            )
            == RetainedStoreInsertResult
                .inserted
        );
    }

    RasterLease!ubyte third;
    size_t thirdBytes;

    assert(
        makeSinglePlaneLease(
            Region2D(
                8,
                0,
                4,
                4
            ),
            0,
            third,
            thirdBytes
        )
    );

    const thirdKey =
        OpaqueKey(
            3,
            0
        );

    const beforeBytes =
        store.retainedBytes;

    assert(
        store.insertOwned(
            thirdKey,
            third
        )
        == RetainedStoreInsertResult
            .entryCapacityExceeded
    );

    assert(store.entryCount == 2);
    assert(store.retainedBytes == beforeBytes);
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            2,
            opaqueHash,
            opaqueEqual
        );

    Store store =
        Store(100);

    RasterLease!ubyte invalid;

    const key =
        OpaqueKey(1, 1);

    assert(
        store.insertOwned(
            key,
            invalid
        )
        == RetainedStoreInsertResult
            .invalidRetainedValue
    );

    assert(store.entryCount == 0);
    assert(store.retainedBytes == 0);
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            CompositeKey,
            2,
            compositeHash,
            compositeEqual
        );

    const region =
        Region2D(
            size_t.max - 10_000,
            size_t.max - 20_000,
            11,
            5
        );

    RasterLease!ubyte lease;
    size_t physicalBytes;

    assert(
        makeInterleavedLease(
            region,
            7,
            lease,
            physicalBytes
        )
    );

    assert(physicalBytes == 145);

    Store store =
        Store(145);

    const key =
        CompositeKey(
            5_001,
            12,
            region,
            44
        );

    assert(
        store.insertOwned(
            key,
            lease
        )
        == RetainedStoreInsertResult
            .inserted
    );

    assert(store.retainedBytes == 145);
    assert(store.entryCount == 1);

    RasterLease!ubyte acquired;

    assert(
        store.tryAcquire(
            key,
            acquired
        )
    );

    assert(
        leaseReadable(
            acquired,
            region
        )
    );
}


unittest
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            OpaqueKey,
            2,
            opaqueHash,
            opaqueEqual
        );

    Store store =
        Store(1_024);

    const region =
        Region2D(
            100,
            200,
            8,
            8
        );

    RasterLease!ubyte lease;
    size_t bytes;

    assert(
        makeSinglePlaneLease(
            region,
            0,
            lease,
            bytes
        )
    );

    const key =
        OpaqueKey(
            9,
            9
        );

    assert(
        store.insertOwned(
            key,
            lease
        )
        == RetainedStoreInsertResult
            .inserted
    );

    RasterLease!ubyte external;

    assert(
        store.tryAcquire(
            key,
            external
        )
    );

    store.clear();

    assert(store.entryCount == 0);
    assert(store.retainedBytes == 0);

    assert(
        leaseReadable(
            external,
            region
        )
    );

    RasterLease!ubyte missing;

    assert(
        !store.tryAcquire(
            key,
            missing
        )
    );
}

} // version (unittest)
