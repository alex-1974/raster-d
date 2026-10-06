/**
 * Public raster fill operation.
 *
 * This module exposes semantic fill behavior only.
 *
 * Execution-layout classification, pointer formation and future fast-path
 * selection remain internal.
 
    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-05
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


/++
    Fills one selected logical destination plane with one exact sample value.

    This is the v0.2 destination-oriented spelling of tryFillRasterPlane().

    Fill has no source operand. The writable destination is therefore the
    semantic subject and remains the first runtime argument:

        fill(destination, planeIndex, value);
        destination.fill(planeIndex, value);

    Semantics are exactly those of tryFillRasterPlane():

    - planeIndex must select a logical destination plane;
    - every validated writable signed affine layout is supported;
    - non-injective mappings are valid because repeated writes of the same
      exact T value are idempotent;
    - an empty selected plane succeeds as a no-op;
    - the operation allocates nothing and retains no operand.

    A second error enum is intentionally not introduced. The existing boolean
    result already completely represents the single request failure category.

    The explicit plane index is a compatibility bridge while
    WritableRasterPlaneView is not yet a production type.
+/
bool fill(T)(
    scope ref WritableRasterView!T destination,
    size_t planeIndex,
    T value
)
@safe
nothrow
@nogc
{
    return tryFillRasterPlane(
        destination,
        planeIndex,
        value
    );
}


/// Example compiling both ordinary and UFCS v0.2 fill forms.
@safe unittest
{
    import raster;

    WritableRasterView!ubyte destination;

    assert(
        !fill(
            destination,
            0,
            cast(ubyte) 7
        )
    );

    assert(
        !destination.fill(
            0,
            cast(ubyte) 7
        )
    );
}

/// Example rejecting a fill when no destination plane exists.
@safe unittest
{
    import raster;
    WritableRasterView!ubyte destination;
    assert(!tryFillRasterPlane(destination, 0, cast(ubyte) 7));
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
            1,
            1
        )
    ];

    scope auto destination =
        makeWritableTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(
                0,
                0,
                0,
                1
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

private struct FillTestPod { uint a; ushort b; ubyte c; ubyte d; }
static assert(FillTestPod.sizeof == 8);

private T fillMatrixValue(T)(bool sentinel)
{
    static if (is(T == float)) return sentinel ? -0.875f : 1.375f;
    else static if (is(T == ubyte)) return sentinel ? 13 : 179;
    else return sentinel ? FillTestPod(7,11,13,17) : FillTestPod(0xa5a55a5a,1234,91,137);
}

private void checkFillLayouts(T)()
{
    // Independent storage oracle covers Canonical and Universal traversal,
    // including the legal non-injective mappings that transform rejects.
    foreach (layout; 0 .. 10)
    {
        ptrdiff_t sr = 8, sx = 1;
        switch (layout)
        {
            case 0: sr = 4; break;
            case 1: break;
            case 2: sr = -8; break;
            case 3: sr = 0; break;
            case 4: sr = 2; break;
            case 5: sr = -2; break;
            case 6: sx = 2; sr = 12; break;
            case 7: sx = -2; sr = -12; break;
            case 8: sx = 0; sr = 3; break;
            case 9: sx = 0; sr = 0; break;
            default: assert(0);
        }
        T[64] storage, expected;
        storage[] = fillMatrixValue!T(true);
        expected[] = fillMatrixValue!T(true);
        const value = fillMatrixValue!T(false);
        const ptrdiff_t offset = 8 + (sr < 0 ? -2*sr : 0) + (sx < 0 ? -3*sx : 0);
        foreach (y; 0 .. 3) foreach (x; 0 .. 4)
            expected[cast(size_t)(offset + cast(ptrdiff_t)y*sr + cast(ptrdiff_t)x*sx)] = value;
        const PlaneDescriptor[1] ds = [PlaneDescriptor(storage.ptr+offset,sr,sx)];
        const ResourceEntry[1] rs = [ResourceEntry(storage.ptr,storage.sizeof,null,null,ResourceAccess.readWrite)];
        scope auto view = makeWritableTestView!T(rs[],ds[],Region2D(0,0,4,3));
        assert(tryFillRasterPlane(view,0,value));
        assert(storage == expected);
    }
}

unittest
{
    checkFillLayouts!float();
    checkFillLayouts!ubyte();
    checkFillLayouts!FillTestPod();
}

unittest
{
    union FloatBits { float value; uint bits; }
    foreach (representation; [0u,0x80000000u,0x7fc12345u,0x7f800000u,0xff800000u])
    foreach (stride; [ptrdiff_t(8),ptrdiff_t(0),ptrdiff_t(-2)])
    {
        FloatBits value; value.bits = representation;
        float[32] storage; storage[] = -1.0f;
        float[32] expected; expected[] = -1.0f;
        const ptrdiff_t offset = stride < 0 ? 4 : 0;
        foreach (y; 0 .. 3) foreach (x; 0 .. 4)
            expected[cast(size_t)(offset+cast(ptrdiff_t)y*stride+cast(ptrdiff_t)x)] = value.value;
        const PlaneDescriptor[1] ds = [PlaneDescriptor(storage.ptr+offset,stride,1)];
        const ResourceEntry[1] rs = [ResourceEntry(storage.ptr,storage.sizeof,null,null,ResourceAccess.readWrite)];
        scope auto view = makeWritableTestView!float(rs[],ds[],Region2D(0,0,4,3));
        assert(tryFillRasterPlane(view,0,value.value));
        foreach (i; 0 .. storage.length)
        {
            FloatBits actual, wanted;
            actual.value = storage[i]; wanted.value = expected[i];
            assert(actual.bits == wanted.bits);
        }
    }
}

} // version (unittest)
