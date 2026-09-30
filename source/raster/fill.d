/**
 * Public raster fill operation.
 *
 * This module exposes semantic fill behavior only.
 *
 * Execution-layout classification, pointer formation and future fast-path
 * selection remain internal.
 */
module raster.fill;

import raster.internal.fill_dispatch :
    tryFillRasterPlaneScalar;

import raster.writable_view :
    WritableRasterView;


/++
    Fills one logical destination plane with one exact sample value.

    Every validated writable resident layout is semantically supported,
    including positive/negative strides and valid non-injective mappings.

    Non-injective mappings are well-defined for fill because every logical
    coordinate writes the same exact T value. Repeated writes to one reachable
    sample start are therefore idempotent.

    A valid empty destination plane succeeds as a no-op.

    Returns false only when planeIndex does not select a logical destination
    plane.

    The operation is allocation-free and retains no operand.
+/
bool tryFillRasterPlane(T)(
    scope ref WritableRasterView!T destination,
    size_t planeIndex,
    T value
)
@safe
nothrow
@nogc
{
    return
        tryFillRasterPlaneScalar(
            destination,
            planeIndex,
            value
        );
}


version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.region :
    Region2D;

import raster.resource :
    ResourceAccess,
    ResourceEntry;

import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import raster.writable_view :
    tryMakeWritableRasterView;


private
WritableRasterView!T makeWritableTestView(T)(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!T(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


unittest
{
    ubyte[6] storage =
        [1, 2, 3, 4, 5, 6];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 3, 2)
        );

    assert(
        tryFillRasterPlane(
            destination,
            0,
            cast(ubyte) 77
        )
    );

    assert(
        storage
        == [77, 77, 77, 77, 77, 77]
    );
}


unittest
{
    /*
     * Padded rows: padding must remain untouched.
     */
    ubyte[10] storage =
        [1, 2, 3, 90, 91, 4, 5, 6, 92, 93];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            5,
            1
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 3, 2)
        );

    assert(
        tryFillRasterPlane(
            destination,
            0,
            cast(ubyte) 9
        )
    );

    assert(
        storage
        == [9, 9, 9, 90, 91, 9, 9, 9, 92, 93]
    );
}


unittest
{
    /*
     * Interleaved logical planes: fill only one plane.
     */
    ubyte[12] storage =
    [
        1, 10,
        2, 20,
        3, 30,
        4, 40,
        5, 50,
        6, 60
    ];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[2] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            6,
            2
        ),
        PlaneDescriptor(
            storage.ptr + 1,
            6,
            2
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 3, 2)
        );

    assert(
        tryFillRasterPlane(
            destination,
            1,
            cast(ubyte) 99
        )
    );

    assert(
        storage
        == [
            1, 99,
            2, 99,
            3, 99,
            4, 99,
            5, 99,
            6, 99
        ]
    );
}


unittest
{
    /*
     * Negative row and sample strides remain valid.
     */
    ubyte[6] storage =
        [1, 2, 3, 4, 5, 6];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr + 5,
            -3,
            -1
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 3, 2)
        );

    assert(
        tryFillRasterPlane(
            destination,
            0,
            cast(ubyte) 44
        )
    );

    assert(
        storage
        == [44, 44, 44, 44, 44, 44]
    );
}


unittest
{
    /*
     * Non-injective zero-stride mappings are semantically valid for fill.
     */
    ubyte[1] storage =
        [3];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            0,
            0
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 4, 3)
        );

    assert(
        tryFillRasterPlane(
            destination,
            0,
            cast(ubyte) 88
        )
    );

    assert(storage[0] == 88);
}


unittest
{
    /*
     * Invalid plane fails without modifying storage.
     */
    ubyte[2] storage =
        [7, 8];

    const auto expected =
        storage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 2, 1)
        );

    assert(
        !tryFillRasterPlane(
            destination,
            1,
            cast(ubyte) 99
        )
    );

    assert(storage == expected);
}


unittest
{
    /*
     * Empty valid plane succeeds without touching storage.
     */
    ubyte[1] storage =
        [17];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            ptrdiff_t.min,
            ptrdiff_t.min
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(
                size_t.max,
                size_t.max,
                0,
                7
            )
        );

    assert(
        tryFillRasterPlane(
            destination,
            0,
            cast(ubyte) 55
        )
    );

    assert(storage[0] == 17);
}


private
struct PairSample
{
    ushort a;
    ushort b;
}


unittest
{
    /*
     * Fill semantics are representation-generic, not numeric-only.
     */
    PairSample[3] storage;

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.length * PairSample.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    scope auto destination =
        makeWritableTestView!PairSample(
            resources[],
            descriptors[],
            Region2D(0, 0, 3, 1)
        );

    const value =
        PairSample(
            123,
            456
        );

    assert(
        tryFillRasterPlane(
            destination,
            0,
            value
        )
    );

    foreach (sample; storage)
    {
        assert(sample == value);
    }
}

} // version (unittest)
