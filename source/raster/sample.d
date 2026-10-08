/++
    Raster sample-type constraints.

    Raster storage is interpreted as raw externally managed bytes. A sample
    type must therefore be safely loadable and copyable without hidden
    ownership, destruction, or indirection semantics.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-05
+/
module raster.sample;

import std.traits :
    Unqual,
    hasIndirections;


/++
    Whether T is supported as a raw raster sample representation.

    Supported sample types are:

    - unqualified value types;
    - POD;
    - free of pointer/reference-like indirections.

    This intentionally permits plain numeric types, static arrays of such
    types, and POD pixel structs without indirections.

    It intentionally rejects:

    - void;
    - const/immutable/shared-qualified sample types;
    - pointers;
    - dynamic arrays;
    - classes/references;
    - structs containing indirections;
    - structs with elaborate copy/destruction semantics.

    This trait describes representation safety. It does not imply any
    particular radiometric or pixel-format semantics.
+/
template isRasterSampleType(T)
{
    static if (is(T == void))
    {
        enum isRasterSampleType = false;
    }
    else static if (!is(T == Unqual!T))
    {
        enum isRasterSampleType = false;
    }
    else
    {
        enum isRasterSampleType =
            __traits(isPOD, T)
            && !hasIndirections!T;
    }
}

/// Example checking raw raster sample representations.
@safe unittest
{
    import raster;

    static assert(isRasterSampleType!ubyte);
    static assert(isRasterSampleType!(ubyte[4]));
    static assert(!isRasterSampleType!(ubyte*));
}


/++
    Whether T is one portable numeric raster sample supported by the v0.2
    generic numerical operation families.

    This trait is intentionally narrower than isRasterSampleType.

    Supported:

        byte, ubyte, short, ushort, int, uint, long, ulong, float, double

    real is deliberately excluded because its precision/representation is
    target-dependent.

    Static arrays and POD pixel structs may still be valid raw raster sample
    representations, but they are not scalar numeric samples under this trait.
+/
template isNumericRasterSample(T)
{
    enum isNumericRasterSample =
        isRasterSampleType!T
        && (
            is(T == byte)
            || is(T == ubyte)
            || is(T == short)
            || is(T == ushort)
            || is(T == int)
            || is(T == uint)
            || is(T == long)
            || is(T == ulong)
            || is(T == float)
            || is(T == double)
        );
}

/// Example distinguishing numeric samples from representation-only samples.
@safe unittest
{
    import raster;
    static assert(isNumericRasterSample!float);
    static assert(isNumericRasterSample!ulong);
    static assert(!isNumericRasterSample!real);
    static assert(!isNumericRasterSample!(ubyte[4]));
}



/++
    Whether every possible From value is exactly representable in To under the
    v0.2 exact raster conversion policy.

    This is a universal type relation, not a runtime value test.

    Exact integer conversion requires complete source-range containment.

    Exact integer-to-floating conversion requires the entire integer domain to
    fit within the destination significand precision.

    Exact floating conversion currently permits identity and float -> double.

    Floating -> integer and double -> float are not universally exact.

    Both From and To must satisfy isNumericRasterSample.
+/
template isExactConvertible(
    From,
    To
)
{
    static if (
        !isNumericRasterSample!From
        || !isNumericRasterSample!To
    )
    {
        enum isExactConvertible =
            false;
    }
    else static if (is(From == To))
    {
        enum isExactConvertible =
            true;
    }
    else static if (
        (
            is(From == byte)
            || is(From == short)
            || is(From == int)
            || is(From == long)
        )
        && (
            is(To == byte)
            || is(To == short)
            || is(To == int)
            || is(To == long)
        )
    )
    {
        enum isExactConvertible =
            From.sizeof <= To.sizeof;
    }
    else static if (
        (
            is(From == ubyte)
            || is(From == ushort)
            || is(From == uint)
            || is(From == ulong)
        )
        && (
            is(To == ubyte)
            || is(To == ushort)
            || is(To == uint)
            || is(To == ulong)
        )
    )
    {
        enum isExactConvertible =
            From.sizeof <= To.sizeof;
    }
    else static if (
        (
            is(From == ubyte)
            || is(From == ushort)
            || is(From == uint)
            || is(From == ulong)
        )
        && (
            is(To == byte)
            || is(To == short)
            || is(To == int)
            || is(To == long)
        )
    )
    {
        enum isExactConvertible =
            From.sizeof < To.sizeof;
    }
    else static if (
        is(To == float)
    )
    {
        enum isExactConvertible =
            is(From == byte)
            || is(From == ubyte)
            || is(From == short)
            || is(From == ushort);
    }
    else static if (
        is(To == double)
    )
    {
        enum isExactConvertible =
            is(From == byte)
            || is(From == ubyte)
            || is(From == short)
            || is(From == ushort)
            || is(From == int)
            || is(From == uint)
            || is(From == float);
    }
    else
    {
        enum isExactConvertible =
            false;
    }
}


/// Example checking semantic sample capabilities.
@safe unittest
{
    import raster;

    static assert(isNumericRasterSample!float);
    static assert(!isNumericRasterSample!real);
    static assert(!isNumericRasterSample!(ubyte[4]));

    static assert(isExactConvertible!(ubyte, float));
    static assert(isExactConvertible!(float, double));
    static assert(!isExactConvertible!(double, float));
}



version (unittest)
{

private
struct PlainRgb
{
    ubyte r;
    ubyte g;
    ubyte b;
}


private
struct PointerSample
{
    ubyte* pointer;
}


private
struct DestructibleSample
{
    ubyte value;

    ~this()
    {
    }
}


static assert(isRasterSampleType!ubyte);
static assert(isRasterSampleType!ushort);
static assert(isRasterSampleType!uint);
static assert(isRasterSampleType!float);
static assert(isRasterSampleType!double);

static assert(isRasterSampleType!(float[4]));
static assert(isRasterSampleType!PlainRgb);

static assert(!isRasterSampleType!void);

static assert(
    !isRasterSampleType!(const ubyte)
);

static assert(
    !isRasterSampleType!(immutable ubyte)
);

static assert(
    !isRasterSampleType!(ubyte*)
);

static assert(
    !isRasterSampleType!(ubyte[])
);

static assert(
    !isRasterSampleType!PointerSample
);

static assert(
    !isRasterSampleType!DestructibleSample
);



static assert(isNumericRasterSample!byte);
static assert(isNumericRasterSample!ubyte);
static assert(isNumericRasterSample!short);
static assert(isNumericRasterSample!ushort);
static assert(isNumericRasterSample!int);
static assert(isNumericRasterSample!uint);
static assert(isNumericRasterSample!long);
static assert(isNumericRasterSample!ulong);
static assert(isNumericRasterSample!float);
static assert(isNumericRasterSample!double);

static assert(!isNumericRasterSample!real);
static assert(!isNumericRasterSample!(float[4]));
static assert(!isNumericRasterSample!PlainRgb);
static assert(!isNumericRasterSample!(ubyte*));

static assert(isExactConvertible!(byte, short));
static assert(isExactConvertible!(ubyte, short));
static assert(isExactConvertible!(uint, long));
static assert(isExactConvertible!(ushort, float));
static assert(isExactConvertible!(int, double));
static assert(isExactConvertible!(uint, double));
static assert(isExactConvertible!(float, double));
static assert(isExactConvertible!(double, double));

static assert(!isExactConvertible!(short, ubyte));
static assert(!isExactConvertible!(int, uint));
static assert(!isExactConvertible!(ulong, long));
static assert(!isExactConvertible!(int, float));
static assert(!isExactConvertible!(long, double));
static assert(!isExactConvertible!(double, float));
static assert(!isExactConvertible!(float, int));
static assert(!isExactConvertible!(real, double));
static assert(!isExactConvertible!(PlainRgb, PlainRgb));

} // version (unittest)
