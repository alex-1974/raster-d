/++
    v0.2 arithmetic convenience wrappers over zipTransformInto().

    These wrappers define common same-type arithmetic without introducing
    separate execution, layout, aliasing, allocation, or failure engines.

    Supported convenience sample types:

        integer:
            byte, ubyte, short, ushort, int, uint, long, ulong

        floating:
            float, double

    Integer add/subtract/multiply results are defined modulo 2^N in the
    destination sample type T. This is explicit raster-d API semantics rather
    than an accidental consequence of integer promotion.

    Floating add/subtract/multiply/divide use D's IEEE-754 floating semantics
    for T, including NaN, infinities, signed zero, overflow and underflow.

    Integer division is deliberately not provided because D runtime integer
    division has undefined cases (zero divisor and signed min / -1) while the
    generic zip primitive has no per-element failure channel. A safe integer
    division policy belongs in a separately specified checked operation.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.arithmetic_into;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;

import raster.zip_transform_into :
    RasterZipTransformError,
    zipTransformInto;


/++
    Whether T is one integer sample type supported by the arithmetic wrappers.

    Character types and bool are deliberately excluded even though D can apply
    integer promotion to them; raster-d does not assign numeric-image semantics
    to those representation types.
+/
private
template isRasterArithmeticInteger(T)
{
    enum isRasterArithmeticInteger =
        is(T == byte)
        || is(T == ubyte)
        || is(T == short)
        || is(T == ushort)
        || is(T == int)
        || is(T == uint)
        || is(T == long)
        || is(T == ulong);
}


/++
    Whether T is one floating sample type supported by the arithmetic wrappers.

    real is deliberately excluded because the workspace does not treat its
    precision/representation as one portable public numerical contract.
+/
private
template isRasterArithmeticFloating(T)
{
    enum isRasterArithmeticFloating =
        is(T == float)
        || is(T == double);
}


private
template isRasterArithmeticSample(T)
{
    enum isRasterArithmeticSample =
        isRasterArithmeticInteger!T
        || isRasterArithmeticFloating!T;
}


/++
    Same-type arithmetic addition.

    Integer result semantics are modulo 2^N in T.

    Floating result semantics are the ordinary D/IEEE-754 result materialized
    as T.
+/
private
T arithmeticAdd(T)(
    T left,
    T right
)
@safe
pure
nothrow
@nogc
{
    static if (isRasterArithmeticInteger!T)
    {
        return cast(T)(
            left + right
        );
    }
    else
    {
        T result =
            left + right;

        return result;
    }
}


/++
    Same-type arithmetic subtraction.

    Integer result semantics are modulo 2^N in T.

    Floating result semantics are the ordinary D/IEEE-754 result materialized
    as T.
+/
private
T arithmeticSubtract(T)(
    T left,
    T right
)
@safe
pure
nothrow
@nogc
{
    static if (isRasterArithmeticInteger!T)
    {
        return cast(T)(
            left - right
        );
    }
    else
    {
        T result =
            left - right;

        return result;
    }
}


/++
    Same-type arithmetic multiplication.

    Integer result semantics are modulo 2^N in T.

    Floating result semantics are the ordinary D/IEEE-754 result materialized
    as T.
+/
private
T arithmeticMultiply(T)(
    T left,
    T right
)
@safe
pure
nothrow
@nogc
{
    static if (isRasterArithmeticInteger!T)
    {
        return cast(T)(
            left * right
        );
    }
    else
    {
        T result =
            left * right;

        return result;
    }
}


/++
    Same-type floating division.

    This helper is instantiated only for float/double by divideInto().
+/
private
T arithmeticDivide(T)(
    T left,
    T right
)
@safe
pure
nothrow
@nogc
{
    static assert(
        isRasterArithmeticFloating!T
    );

    T result =
        left / right;

    return result;
}


/++
    Adds corresponding samples from left and right into destination.

    Supported T:

        byte, ubyte, short, ushort, int, uint, long, ulong, float, double

    Integer result:

        mathematical sum reduced modulo 2^N to T

    Floating result:

        D/IEEE-754 addition in T

    All shape/layout/alias/failure semantics are exactly those of
    zipTransformInto(). In particular:

    - all three selected planes must have matching shape;
    - matching empty shapes are a successful no-op;
    - destination must be injective for non-empty geometry;
    - source/source overlap is allowed;
    - either source overlapping destination is rejected before writing.

    This wrapper allocates nothing and contains no pixel loop.
+/
bool addInto(T)(
    scope RasterView!T left,
    size_t leftPlaneIndex,

    scope RasterView!T right,
    size_t rightPlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterZipTransformError error
)
@safe
nothrow
@nogc
if (isRasterArithmeticSample!T)
{
    return zipTransformInto!(
        arithmeticAdd!T
    )(
        left,
        leftPlaneIndex,
        right,
        rightPlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    );
}

/// Example reporting add failure through the shared zip-transform model.
@safe unittest
{
    import raster;
    RasterView!float left;
    RasterView!float right;
    WritableRasterView!float destination;
    RasterZipTransformError error;
    assert(!addInto(left, 0, right, 0, destination, 0, error));
    assert(error == RasterZipTransformError.invalidLeftPlane);
}



/++
    Subtracts corresponding right samples from left samples into destination.

    Supported T:

        byte, ubyte, short, ushort, int, uint, long, ulong, float, double

    Integer result:

        mathematical difference reduced modulo 2^N to T

    Floating result:

        D/IEEE-754 subtraction in T

    Structural, alias, failure, allocation and execution semantics are inherited
    unchanged from zipTransformInto().
+/
bool subtractInto(T)(
    scope RasterView!T left,
    size_t leftPlaneIndex,

    scope RasterView!T right,
    size_t rightPlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterZipTransformError error
)
@safe
nothrow
@nogc
if (isRasterArithmeticSample!T)
{
    return zipTransformInto!(
        arithmeticSubtract!T
    )(
        left,
        leftPlaneIndex,
        right,
        rightPlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    );
}

/// Example reporting subtract failure through the shared zip-transform model.
@safe unittest
{
    import raster;
    RasterView!float left;
    RasterView!float right;
    WritableRasterView!float destination;
    RasterZipTransformError error;
    assert(!subtractInto(left, 0, right, 0, destination, 0, error));
    assert(error == RasterZipTransformError.invalidLeftPlane);
}



/++
    Multiplies corresponding left/right samples into destination.

    Supported T:

        byte, ubyte, short, ushort, int, uint, long, ulong, float, double

    Integer result:

        mathematical product reduced modulo 2^N to T

    Floating result:

        D/IEEE-754 multiplication in T

    Structural, alias, failure, allocation and execution semantics are inherited
    unchanged from zipTransformInto().
+/
bool multiplyInto(T)(
    scope RasterView!T left,
    size_t leftPlaneIndex,

    scope RasterView!T right,
    size_t rightPlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterZipTransformError error
)
@safe
nothrow
@nogc
if (isRasterArithmeticSample!T)
{
    return zipTransformInto!(
        arithmeticMultiply!T
    )(
        left,
        leftPlaneIndex,
        right,
        rightPlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    );
}

/// Example reporting multiply failure through the shared zip-transform model.
@safe unittest
{
    import raster;
    RasterView!float left;
    RasterView!float right;
    WritableRasterView!float destination;
    RasterZipTransformError error;
    assert(!multiplyInto(left, 0, right, 0, destination, 0, error));
    assert(error == RasterZipTransformError.invalidLeftPlane);
}



/++
    Divides corresponding left samples by right samples into destination.

    Supported T:

        float, double

    Result semantics are D/IEEE-754 floating division in T.

    Therefore, without any raster-d pre-scan or special-case branch:

    - finite nonzero division rounds according to the active IEEE rounding mode;
    - finite nonzero / signed zero produces signed infinity as defined by IEEE;
    - zero / zero produces NaN;
    - finite overflow may produce infinity;
    - underflow may produce a subnormal or signed zero;
    - NaN and infinity propagate according to D/IEEE semantics.

    Integer division is intentionally not part of this wrapper because its
    runtime undefined cases cannot be represented honestly through the existing
    zipTransformInto failure channel without a separate pre-scan or execution
    engine.

    Structural, alias, failure, allocation and execution semantics are inherited
    unchanged from zipTransformInto().
+/
bool divideInto(T)(
    scope RasterView!T left,
    size_t leftPlaneIndex,

    scope RasterView!T right,
    size_t rightPlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterZipTransformError error
)
@safe
nothrow
@nogc
if (isRasterArithmeticFloating!T)
{
    return zipTransformInto!(
        arithmeticDivide!T
    )(
        left,
        leftPlaneIndex,
        right,
        rightPlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    );
}


/// Example showing that arithmetic wrappers preserve zip failure semantics.
@safe unittest
{
    import raster;

    RasterView!float left;
    RasterView!float right;
    WritableRasterView!float destination;

    RasterZipTransformError error;

    assert(
        !left.addInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.invalidLeftPlane
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

import raster.view :
    makeRasterViewAssumeValidated;

import raster.writable_view :
    tryMakeWritableRasterView;


private
WritableRasterView!T makeWritableArithmeticTestView(T)(
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


/*
 * Signed small-integer addition is explicitly modulo the sample width.
 */
@system
unittest
{
    byte[2] leftStorage =
        [byte.max, byte.min];

    byte[2] rightStorage =
        [1, -1];

    byte[2] destinationStorage;

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!byte(
            leftDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!byte(
            rightDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableArithmeticTestView!byte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterZipTransformError error;

    assert(
        left.addInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[0] == byte.min);
    assert(destinationStorage[1] == byte.max);
}


/*
 * Unsigned subtraction wraps modulo the sample width.
 */
@system
unittest
{
    ubyte[2] leftStorage =
        [0, 5];

    ubyte[2] rightStorage =
        [1, 7];

    ubyte[2] destinationStorage;

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(leftStorage.ptr, 2, 1)
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(rightStorage.ptr, 2, 1)
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(destinationStorage.ptr, 2, 1)
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableArithmeticTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterZipTransformError error;

    assert(
        left.subtractInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[0] == ubyte.max);
    assert(destinationStorage[1] == 254);
}


/*
 * Multiplication is modulo T width even when D integer promotion evaluates
 * small operands as int first.
 */
@system
unittest
{
    ushort[2] leftStorage =
        [ushort.max, 40000];

    ushort[2] rightStorage =
        [2, 2];

    ushort[2] destinationStorage;

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(leftStorage.ptr, 2, 1)
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(rightStorage.ptr, 2, 1)
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(destinationStorage.ptr, 2, 1)
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ushort(
            leftDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ushort(
            rightDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableArithmeticTestView!ushort(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterZipTransformError error;

    assert(
        left.multiplyInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[0] == 65534);
    assert(destinationStorage[1] == 14464);
}


/*
 * Full-width signed overflow is also modulo two's-complement T width.
 */
@system
unittest
{
    int[1] leftStorage =
        [int.max];

    int[1] rightStorage =
        [1];

    int[1] destinationStorage;

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(leftStorage.ptr, 1, 1)
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(rightStorage.ptr, 1, 1)
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(destinationStorage.ptr, 1, 1)
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!int(
            leftDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!int(
            rightDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    scope auto destination =
        makeWritableArithmeticTestView!int(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    RasterZipTransformError error;

    assert(
        left.addInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[0] == int.min);
}


/*
 * Float divide preserves IEEE special-value behavior without a pre-scan.
 */
@system
unittest
{
    float[4] leftStorage =
        [1.0f, -1.0f, 0.0f, 6.0f];

    float[4] rightStorage =
        [0.0f, 0.0f, 0.0f, 2.0f];

    float[4] destinationStorage;

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(leftStorage.ptr, 4, 1)
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(rightStorage.ptr, 4, 1)
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(destinationStorage.ptr, 4, 1)
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!float(
            leftDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!float(
            rightDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    scope auto destination =
        makeWritableArithmeticTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    RasterZipTransformError error;

    assert(
        left.divideInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[0] == float.infinity);
    assert(destinationStorage[1] == -float.infinity);
    assert(destinationStorage[2] != destinationStorage[2]);
    assert(destinationStorage[3] == 3.0f);
}


/*
 * Signed-stride layout behavior remains zipTransformInto behavior.
 */
@system
unittest
{
    ubyte[8] leftStorage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    ubyte[8] rightStorage =
        [10, 88, 20, 88, 30, 88, 40, 88];

    ubyte[8] destinationStorage =
        [0, 77, 0, 77, 0, 77, 0, 77];

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
            4,
            2
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableArithmeticTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterZipTransformError error;

    assert(
        left.addInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[6] == 14);
    assert(destinationStorage[4] == 23);
    assert(destinationStorage[2] == 32);
    assert(destinationStorage[0] == 41);

    assert(destinationStorage[1] == 77);
    assert(destinationStorage[3] == 77);
    assert(destinationStorage[5] == 77);
    assert(destinationStorage[7] == 77);
}


/*
 * Wrapper failure semantics are delegated unchanged.
 */
@system
unittest
{
    ubyte[2] leftStorage =
        [1, 2];

    ubyte[3] rightStorage =
        [10, 20, 30];

    ubyte[2] destinationStorage =
        [44, 44];

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(leftStorage.ptr, 2, 1)
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(rightStorage.ptr, 3, 1)
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(destinationStorage.ptr, 2, 1)
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    scope auto destination =
        makeWritableArithmeticTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterZipTransformError error;

    assert(
        !left.addInto(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.shapeMismatch
    );

    assert(destinationStorage == [44, 44]);
}


/*
 * Integer division is not part of the convenience family.
 */
static assert(
    !__traits(
        compiles,
        {
            RasterView!int left;
            RasterView!int right;
            WritableRasterView!int destination;
            RasterZipTransformError error;

            left.divideInto(
                0,
                right,
                0,
                destination,
                0,
                error
            );
        }
    )
);


/*
 * Representation-only raster sample types remain available to the generic zip
 * primitive but are intentionally rejected by arithmetic convenience wrappers.
 */
private
struct PairSample
{
    ushort first;
    ushort second;
}

static assert(
    !__traits(
        compiles,
        {
            RasterView!PairSample left;
            RasterView!PairSample right;
            WritableRasterView!PairSample destination;
            RasterZipTransformError error;

            left.addInto(
                0,
                right,
                0,
                destination,
                0,
                error
            );
        }
    )
);


} // version (unittest)
