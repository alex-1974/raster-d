/++
    Generic raster border policy types.

    Policy selection is type-level so spatial kernels can specialize without a
    runtime per-sample mode branch.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.border_policy;

import raster.sample :
    isRasterSampleType;


/++
    Semantic identity of one generic raster border policy.
+/
enum RasterBorderKind : ubyte
{
    valid,
    constant,
    clamp,
    mirror,
    wrap
}

/// Example naming the stable border policy categories.
@safe unittest
{
    import raster;
    assert(RasterBorderKind.valid != RasterBorderKind.constant);
    assert(RasterBorderKind.clamp != RasterBorderKind.wrap);
}



/++
    Valid-only border policy.

    No outside sample is synthesized.

    A spatial operation using this policy succeeds only when every required
    source coordinate is already resident/valid under that operation's source
    contract.

    This is the semantic behavior of the existing neighbourhood primitives.
+/
struct RasterValidBorder
{
    enum RasterBorderKind kind =
        RasterBorderKind.valid;
}

/// Example selecting valid-only border semantics.
@safe unittest
{
    import raster;
    static assert(RasterValidBorder.kind == RasterBorderKind.valid);
}



/++
    Constant border policy.

    Coordinates outside the valid source extent produce value.

    Coordinates inside the source extent are read from the source unchanged.

    The policy carries exactly one runtime sample value because the constant is
    ordinary caller data rather than compile-time semantics.
+/
struct RasterConstantBorder(T)
if (isRasterSampleType!T)
{
    enum RasterBorderKind kind =
        RasterBorderKind.constant;

    T value;
}

/// Example carrying a constant border value.
@safe unittest
{
    import raster;
    const border = RasterConstantBorder!ubyte(17);
    assert(border.value == 17);
    static assert(RasterConstantBorder!ubyte.kind == RasterBorderKind.constant);
}



/++
    Clamp border policy.

    Each outside coordinate is mapped to the nearest valid edge coordinate.

    For one axis with extent N > 0:

        c < 0   -> 0
        c >= N  -> N - 1
        otherwise c

    The policy is undefined for zero extent and an operation must reject such a
    request before attempting clamp mapping.
+/
struct RasterClampBorder
{
    enum RasterBorderKind kind =
        RasterBorderKind.clamp;
}

/// Example selecting clamp border semantics.
@safe unittest
{
    import raster;
    static assert(RasterClampBorder.kind == RasterBorderKind.clamp);
}



/++
    Mirror border policy using edge-inclusive symmetric reflection.

    For one axis with extent N > 0, coordinates follow a 2*N period.

    For N = 4 the infinite index pattern is:

        ... 2 3 | 3 2 1 0 | 0 1 2 3 | 3 2 1 0 | 0 1 ...

    Thus both edge samples are repeated at reflection boundaries.

    Equivalently, with r = euclideanModulo(c, 2*N):

        r < N   -> r
        otherwise 2*N - 1 - r

    This definition intentionally distinguishes raster-d mirror semantics from
    alternative reflect-without-edge-repeat conventions.

    The policy is undefined for zero extent and an operation must reject such a
    request before attempting mirror mapping.
+/
struct RasterMirrorBorder
{
    enum RasterBorderKind kind =
        RasterBorderKind.mirror;
}

/// Example selecting edge-inclusive mirror border semantics.
@safe unittest
{
    import raster;
    static assert(RasterMirrorBorder.kind == RasterBorderKind.mirror);
}



/++
    Wrap border policy.

    For one axis with extent N > 0, an arbitrary integer coordinate c maps to:

        euclideanModulo(c, N)

    Negative coordinates therefore wrap from the opposite edge rather than
    using implementation-language remainder semantics.

    The policy is undefined for zero extent and an operation must reject such a
    request before attempting wrap mapping.
+/
struct RasterWrapBorder
{
    enum RasterBorderKind kind =
        RasterBorderKind.wrap;
}


/// Example selecting compile-time border policies.
@safe unittest
{
    import raster;

    static assert(
        RasterValidBorder.kind
        == RasterBorderKind.valid
    );

    static assert(
        RasterClampBorder.kind
        == RasterBorderKind.clamp
    );

    static assert(
        RasterMirrorBorder.kind
        == RasterBorderKind.mirror
    );

    static assert(
        RasterWrapBorder.kind
        == RasterBorderKind.wrap
    );

    RasterConstantBorder!ubyte constant =
        RasterConstantBorder!ubyte(17);

    assert(constant.value == 17);

    static assert(
        typeof(constant).kind
        == RasterBorderKind.constant
    );
}


version (unittest)
{

/*
 * Stateless policies contain no runtime fields.
 */
static assert(RasterValidBorder.tupleof.length == 0);
static assert(RasterClampBorder.tupleof.length == 0);
static assert(RasterMirrorBorder.tupleof.length == 0);
static assert(RasterWrapBorder.tupleof.length == 0);


/*
 * Constant carries exactly the caller-selected sample value.
 */
static assert(
    RasterConstantBorder!ubyte.tupleof.length
    == 1
);

static assert(
    RasterConstantBorder!(ubyte[4]).tupleof.length
    == 1
);


private
struct PlainBorderSample
{
    ushort a;
    ushort b;
}


static assert(
    isRasterSampleType!PlainBorderSample
);

static assert(
    RasterConstantBorder!PlainBorderSample.tupleof.length
    == 1
);

} // version (unittest)
