/++
    Checked conservative bounds for invocation-local validated raster relations.

    Only provably disjoint byte envelopes bypass exact sample-byte
    classification. Overlapping or unrepresentable envelopes prove nothing.

    Qualified research: raster-d-research Issue #15, head
    59dcdbb8098e070f3ae2d8c75c8de1a766889f0e; ADR 0010.
+/
module raster.internal.validated_affine_relation;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    classifySameTypeAffine2DRectanglesByteOverlap,
    classifyUbyteToFloatAffine2DByteOverlap;

private
struct Rect
{
    size_t width;
    size_t height;
    size_t base;
    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
}

private
struct Bound
{
    size_t start;
    size_t length;
    bool valid;
}

/++
    Returns true when two checked inclusive byte-address bounds are provably disjoint.
+/
private
bool boundsDisjoint(Bound a, Bound b)
@safe pure nothrow @nogc
{
    assert(a.valid);
    assert(b.valid);

    if (a.length > size_t.max - a.start)
        return false;
    if (b.length > size_t.max - b.start)
        return false;

    const aEnd = a.start + a.length;
    const bEnd = b.start + b.length;

    return aEnd <= b.start || bEnd <= a.start;
}

/++
    Multiplies one validated coordinate by a signed stride with representability checking.
+/
private
bool checkedCoordinateStride(
    size_t coordinate,
    ptrdiff_t stride,
    out ptrdiff_t result
)
@safe pure nothrow @nogc
{
    result = 0;

    if (coordinate == 0 || stride == 0)
        return true;

    if (stride > 0)
    {
        const magnitude = cast(size_t)stride;
        const limit = cast(size_t)ptrdiff_t.max;

        if (coordinate > limit / magnitude)
            return false;

        result =
            cast(ptrdiff_t)(coordinate * magnitude);

        return true;
    }

    const negativeLimit =
        cast(size_t)ptrdiff_t.max + 1;

    const magnitude =
        stride == ptrdiff_t.min
        ? negativeLimit
        : cast(size_t)(-stride);

    if (coordinate > negativeLimit / magnitude)
        return false;

    const product = coordinate * magnitude;

    if (product == negativeLimit)
        result = ptrdiff_t.min;
    else
        result = -cast(ptrdiff_t)product;

    return true;
}


/++
    Adds two ptrdiff_t values with explicit overflow detection.
+/
private
bool checkedAddPtrdiff(
    ptrdiff_t left,
    ptrdiff_t right,
    out ptrdiff_t result
)
@safe pure nothrow @nogc
{
    result = 0;

    if (
        right > 0
        && left > ptrdiff_t.max - right
    )
        return false;

    if (
        right < 0
        && left < ptrdiff_t.min - right
    )
        return false;

    result = left + right;
    return true;
}


/++
    Returns the unsigned magnitude of a signed ptrdiff_t without negating ptrdiff_t.min.
+/
private
size_t ptrdiffMagnitude(ptrdiff_t value)
@safe pure nothrow @nogc
{
    if (value >= 0)
        return cast(size_t)value;

    if (value == ptrdiff_t.min)
        return cast(size_t)ptrdiff_t.max + 1;

    return cast(size_t)(-value);
}


/++
    Converts a checked element offset into a checked byte offset for one sample size.
+/
private
bool checkedOffsetBytes(
    ptrdiff_t elementOffset,
    size_t sampleSize,
    out size_t byteMagnitude
)
@safe pure nothrow @nogc
{
    byteMagnitude = 0;

    if (sampleSize == 0)
        return false;

    const magnitude =
        ptrdiffMagnitude(elementOffset);

    if (magnitude > size_t.max / sampleSize)
        return false;

    byteMagnitude = magnitude * sampleSize;
    return true;
}


/++
    Computes the minimum and maximum checked offsets contributed by one zero-origin raster axis.
+/
private
bool checkedAxisOffsetsZeroOrigin(
    size_t extent,
    ptrdiff_t stride,
    out ptrdiff_t minimum,
    out ptrdiff_t maximum
)
@safe pure nothrow @nogc
{
    minimum = 0;
    maximum = 0;

    if (extent == 0)
        return false;

    ptrdiff_t lastOffset;

    if (
        !checkedCoordinateStride(
            extent - 1,
            stride,
            lastOffset
        )
    )
        return false;

    if (lastOffset < 0)
        minimum = lastOffset;
    else
        maximum = lastOffset;

    return true;
}


/++
    Adds a checked signed element offset to a validated base address and returns the resulting byte address.
+/
private
bool checkedAddressFromElementOffset(
    size_t base,
    ptrdiff_t elementOffset,
    size_t sampleSize,
    out size_t address
)
@safe pure nothrow @nogc
{
    address = 0;

    size_t byteMagnitude;

    if (
        !checkedOffsetBytes(
            elementOffset,
            sampleSize,
            byteMagnitude
        )
    )
        return false;

    if (elementOffset < 0)
    {
        if (byteMagnitude > base)
            return false;

        address = base - byteMagnitude;
        return true;
    }

    if (byteMagnitude > size_t.max - base)
        return false;

    address = base + byteMagnitude;
    return true;
}


/++
    Computes one checked inclusive physical byte bound for a validated affine raster rectangle.
+/
private
Bound checkedAffineBound(Rect rect, size_t sampleSize)
@safe pure nothrow @nogc
{
    if (
        rect.width == 0
        || rect.height == 0
        || sampleSize == 0
    )
        return Bound.init;

    ptrdiff_t xMinimum;
    ptrdiff_t xMaximum;

    if (
        !checkedAxisOffsetsZeroOrigin(
            rect.width,
            rect.sampleStride,
            xMinimum,
            xMaximum
        )
    )
        return Bound.init;

    ptrdiff_t yMinimum;
    ptrdiff_t yMaximum;

    if (
        !checkedAxisOffsetsZeroOrigin(
            rect.height,
            rect.rowStride,
            yMinimum,
            yMaximum
        )
    )
        return Bound.init;

    ptrdiff_t minimumOffset;
    ptrdiff_t maximumOffset;

    if (
        !checkedAddPtrdiff(
            xMinimum,
            yMinimum,
            minimumOffset
        )
        ||
        !checkedAddPtrdiff(
            xMaximum,
            yMaximum,
            maximumOffset
        )
    )
        return Bound.init;

    size_t lower;
    size_t upperSample;

    if (
        !checkedAddressFromElementOffset(
            rect.base,
            minimumOffset,
            sampleSize,
            lower
        )
        ||
        !checkedAddressFromElementOffset(
            rect.base,
            maximumOffset,
            sampleSize,
            upperSample
        )
    )
        return Bound.init;

    if (upperSample < lower)
        return Bound.init;

    if (sampleSize > size_t.max - upperSample)
        return Bound.init;

    const upperEnd =
        upperSample + sampleSize;

    return Bound(
        lower,
        upperEnd - lower,
        true
    );
}


/++
    Attempts the conservative checked-bounds fast reject used before exact affine-overlap classification.
+/
private
bool checkedFastRejectDisjoint(
    Rect a,
    Rect b,
    size_t sampleSize
)
@safe pure nothrow @nogc
{
    if (
        a.width == 0 || a.height == 0
        || b.width == 0 || b.height == 0
    )
        return true;

    const ab = checkedAffineBound(a, sampleSize);
    const bb = checkedAffineBound(b, sampleSize);

    return ab.valid && bb.valid && boundsDisjoint(ab, bb);
}


/++
    Classifies differently shaped same-type rectangles originating from
    validated RasterView/WritableRasterView sample bytes.

    Strides are in sample elements. Bases identify each rectangle's logical
    (0, 0) sample. This function dereferences no pointers and proves no
    ownership, exclusivity or persistent noalias property.

    Checked half-open bounds are solely a sufficient disjointness proof.
    Otherwise the existing exact algebraic classifier determines the result,
    including arithmeticFailure. The caller retains its defensive fallback.
+/
/++
    Classifies exact byte overlap between two validated same-type affine rectangles, using checked bounds only as a conservative early reject.
+/
package(raster)
AffineByteOverlapRelation classifyValidatedSameTypeAffine2DRectanglesByteOverlap(
    size_t sourceWidth,
    size_t sourceHeight,
    size_t sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,
    size_t targetWidth,
    size_t targetHeight,
    size_t targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,
    size_t sampleSize
)
@safe pure nothrow @nogc
{
    if (checkedFastRejectDisjoint(
        Rect(sourceWidth, sourceHeight, sourceBase,
            sourceRowStrideElements, sourceSampleStrideElements),
        Rect(targetWidth, targetHeight, targetBase,
            targetRowStrideElements, targetSampleStrideElements),
        sampleSize
    ))
        return AffineByteOverlapRelation.disjoint;

    return classifySameTypeAffine2DRectanglesByteOverlap(
        sourceWidth, sourceHeight, sourceBase,
        sourceRowStrideElements, sourceSampleStrideElements,
        targetWidth, targetHeight, targetBase,
        targetRowStrideElements, targetSampleStrideElements,
        sampleSize
    );
}


/++
    Equal-shape convenience wrapper for the same invocation-local validated
    same-type relation. Error and fallback semantics match the rectangle form.
+/
/++
    Classifies exact byte overlap between two equally shaped validated same-type affine mappings.
+/
package(raster)
AffineByteOverlapRelation classifyValidatedSameTypeAffine2DByteOverlap(
    size_t width,
    size_t height,
    size_t sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,
    size_t targetBase,
    ptrdiff_t targetRowStrideElements,
    ptrdiff_t targetSampleStrideElements,
    size_t sampleSize
)
@safe pure nothrow @nogc
{
    return classifyValidatedSameTypeAffine2DRectanglesByteOverlap(
        width, height, sourceBase,
        sourceRowStrideElements, sourceSampleStrideElements,
        width, height, targetBase,
        targetRowStrideElements, targetSampleStrideElements,
        sampleSize
    );
}


version (unittest)
{

private AffineByteOverlapRelation classify(Rect a, Rect b, size_t sampleSize)
@safe pure nothrow @nogc
{
    return classifyValidatedSameTypeAffine2DRectanglesByteOverlap(
        a.width, a.height, a.base, a.rowStride, a.sampleStride,
        b.width, b.height, b.base, b.rowStride, b.sampleStride, sampleSize);
}

private AffineByteOverlapRelation exact(Rect a, Rect b, size_t sampleSize)
@safe pure nothrow @nogc
{
    return classifySameTypeAffine2DRectanglesByteOverlap(
        a.width, a.height, a.base, a.rowStride, a.sampleStride,
        b.width, b.height, b.base, b.rowStride, b.sampleStride, sampleSize);
}

// Integer limits only: no fabricated pointer is dereferenced.
unittest
{
    const signBit = cast(size_t)ptrdiff_t.max + 1;
    struct Fixture { Rect a; Rect b; size_t size; bool rejects; }
    const Fixture[] fixtures = [
        Fixture(Rect(1,1,0,ptrdiff_t.min,ptrdiff_t.max), Rect(1,1,size_t.max-1,0,0),1,true),
        Fixture(Rect(1,1,size_t.max-8,0,0), Rect(1,1,0,0,0),8,true),
        Fixture(Rect(1,1,size_t.max-6,0,0), Rect(1,1,0,0,0),8,false),
        Fixture(Rect(2,1,signBit,0,ptrdiff_t.min), Rect(1,1,size_t.max-1,0,0),1,true),
        Fixture(Rect(2,1,0,0,ptrdiff_t.max), Rect(1,1,size_t.max-1,0,0),1,true),
        Fixture(Rect(2,2,signBit,ptrdiff_t.min,ptrdiff_t.min), Rect(1,1,0,0,0),1,false),
        Fixture(Rect(3,1,0,0,ptrdiff_t.max), Rect(1,1,0,0,0),1,false),
        Fixture(Rect(2,1,0,0,ptrdiff_t.max), Rect(1,1,0,0,0),8,false),
        Fixture(Rect(2,1,size_t.max-1,0,-1), Rect(1,1,0,0,0),1,true),
        Fixture(Rect(2,1,1,0,-1), Rect(2,1,size_t.max-2,0,1),1,true),
        Fixture(Rect(4,1,64,0,2), Rect(4,1,65,0,2),1,false),
        Fixture(Rect(4,1,64,0,2), Rect(4,1,66,0,2),1,false)
    ];
    foreach (f; fixtures)
    {
        assert(checkedFastRejectDisjoint(f.a, f.b, f.size) == f.rejects);
        assert(classify(f.a, f.b, f.size) == exact(f.a, f.b, f.size));
        assert(classify(f.b, f.a, f.size) == classify(f.a, f.b, f.size));
    }
    assert(classify(fixtures[10].a, fixtures[10].b, 1) == AffineByteOverlapRelation.disjoint);
    assert(classify(fixtures[11].a, fixtures[11].b, 1) == AffineByteOverlapRelation.overlap);
    assert(classify(Rect(1,1,64,0,1), Rect(1,1,128,0,1), 0)
        == AffineByteOverlapRelation.arithmeticFailure);
    assert(classify(Rect(0,1,64,0,1), Rect(1,1,128,0,1), 0)
        == exact(Rect(0,1,64,0,1), Rect(1,1,128,0,1), 0));
    assert(checkedFastRejectDisjoint(Rect(1,1,64,0,1), Rect(1,1,65,0,1), 1));
}

// Independent byte-distance oracle in a bounded domain. All addresses stay
// positive and far below the limits; signed long arithmetic is exact here.
unittest
{
    uint state = 0x91e10da5;
    uint nextWord() @safe nothrow @nogc
    {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
    }
    size_t fastRejects;
    size_t fallbacks;
    size_t overlaps;
    foreach (iteration; 0 .. 5000)
    {
        const size = size_t(1) << (nextWord() % 4);
        const a = Rect(nextWord()%5, nextWord()%5, 2048+nextWord()%512,
            cast(ptrdiff_t)(nextWord()%15)-7, cast(ptrdiff_t)(nextWord()%15)-7);
        const b = Rect(nextWord()%5, nextWord()%5, 2048+nextWord()%512,
            cast(ptrdiff_t)(nextWord()%15)-7, cast(ptrdiff_t)(nextWord()%15)-7);
        bool overlap;
        foreach (ay; 0 .. a.height)
        foreach (ax; 0 .. a.width)
        foreach (by; 0 .. b.height)
        foreach (bx; 0 .. b.width)
        {
            const as = cast(long)a.base + (cast(long)ay*a.rowStride + cast(long)ax*a.sampleStride)*cast(long)size;
            const bs = cast(long)b.base + (cast(long)by*b.rowStride + cast(long)bx*b.sampleStride)*cast(long)size;
            const distance = as > bs ? as-bs : bs-as;
            overlap |= distance < cast(long)size;
        }
        const expected = overlap ? AffineByteOverlapRelation.overlap : AffineByteOverlapRelation.disjoint;
        const rejects = checkedFastRejectDisjoint(a,b,size);
        assert(!rejects || !overlap);
        assert(classify(a,b,size) == expected);
        assert(classify(a,b,size) == exact(a,b,size));
        assert(classify(b,a,size) == expected);
        if (rejects) ++fastRejects; else ++fallbacks;
        if (overlap) ++overlaps;
    }
    assert(fastRejects > 0 && fallbacks > 0 && overlaps > 0);
}

// The wrapper retains compile-time evaluation and the checked helper attributes.
static assert(classifyValidatedSameTypeAffine2DByteOverlap(2,2,64,4,-1,128,-4,1,1)
    == AffineByteOverlapRelation.disjoint);

} // version (unittest)

/++
    Proves disjointness from checked one-byte source and four-byte target
    envelopes. Overlapping or unrepresentable envelopes preserve the original
    exact classifier, including arithmeticFailure and the caller's fallback.
    This invocation-local relation performs no pointer access.
+/
/++
    Classifies exact physical overlap between validated ubyte source and float destination affine mappings.
+/
package(raster)
AffineByteOverlapRelation classifyValidatedUbyteToFloatAffine2DByteOverlap(
    size_t width,
    size_t height,
    size_t sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,
    size_t targetBase,
    ptrdiff_t targetRowStride,
    ptrdiff_t targetSampleStride
)
@safe pure nothrow @nogc
{
    if (width == 0 || height == 0)
        return AffineByteOverlapRelation.disjoint;

    const source = checkedAffineBound(
        Rect(width, height, sourceBase, sourceRowStride, sourceSampleStride),
        ubyte.sizeof);
    const target = checkedAffineBound(
        Rect(width, height, targetBase, targetRowStride, targetSampleStride),
        float.sizeof);
    if (source.valid && target.valid && boundsDisjoint(source, target))
        return AffineByteOverlapRelation.disjoint;

    return classifyUbyteToFloatAffine2DByteOverlap(
        width, height, sourceBase, sourceRowStride, sourceSampleStride,
        targetBase, targetRowStride, targetSampleStride);
}

version(unittest)
{
// Independent bounded byte enumeration, never fabricated pointer access.
unittest
{
    uint state=0x123a5b7d;size_t hits,misses,overlaps;
    uint next(){state^=state<<13;state^=state>>17;state^=state<<5;return state;}
    foreach(i;0..5000){
        const w=size_t(next()%5),h=size_t(next()%5);
        const a=size_t(2048+next()%512),b=size_t(2048+next()%512);
        const sr=cast(ptrdiff_t)(next()%15)-7,sx=cast(ptrdiff_t)(next()%15)-7;
        const dr=cast(ptrdiff_t)(next()%15)-7,dx=cast(ptrdiff_t)(next()%15)-7;
        bool overlap;
        foreach(y;0..h)foreach(x;0..w)foreach(v;0..h)foreach(u;0..w){
            const source=cast(long)a+cast(long)y*sr+cast(long)x*sx;
            const target=cast(long)b+(cast(long)v*dr+cast(long)u*dx)*4;
            foreach(byteIndex;0..4)overlap|=source==target+cast(long)byteIndex;
        }
        const expected=overlap ? AffineByteOverlapRelation.overlap : AffineByteOverlapRelation.disjoint;
        const result=classifyValidatedUbyteToFloatAffine2DByteOverlap(w,h,a,sr,sx,b,dr,dx);
        assert(result==expected);
        assert(result==classifyUbyteToFloatAffine2DByteOverlap(w,h,a,sr,sx,b,dr,dx));
        const ab=checkedAffineBound(Rect(w,h,a,sr,sx),1),bb=checkedAffineBound(Rect(w,h,b,dr,dx),4);
        const fast=ab.valid && bb.valid && boundsDisjoint(ab,bb);
        assert(!fast || !overlap);if(fast)++hits;else ++misses;if(overlap)++overlaps;
    }
    assert(hits>0 && misses>0 && overlaps>0);
}
// Checked arithmetic limits are compared with the exact original result.
unittest
{
    struct F{size_t w,h,a,b;ptrdiff_t sr,sx,dr,dx;}
    const limit=cast(size_t)ptrdiff_t.max+1;
    F[] fixtures=[
        F(1,1,0,size_t.max-3,ptrdiff_t.min,ptrdiff_t.min,0,0),
        F(1,1,size_t.max-1,0,0,0,ptrdiff_t.min,ptrdiff_t.max),
        F(2,2,limit,0,ptrdiff_t.min,ptrdiff_t.min,1,1),
        F(3,1,0,0,0,ptrdiff_t.max,0,1),
        F(2,1,0,size_t.max-1,0,1,0,ptrdiff_t.max),
        F(4,1,64,65,0,8,0,2), // overlapping envelopes, disjoint bytes
        F(4,1,64,64,0,8,0,2)  // actual byte overlap
    ];
    foreach(f;fixtures)assert(classifyValidatedUbyteToFloatAffine2DByteOverlap(f.w,f.h,f.a,f.sr,f.sx,f.b,f.dr,f.dx)
        ==classifyUbyteToFloatAffine2DByteOverlap(f.w,f.h,f.a,f.sr,f.sx,f.b,f.dr,f.dx));
    assert(classifyValidatedUbyteToFloatAffine2DByteOverlap(4,1,64,0,8,65,0,2)==AffineByteOverlapRelation.disjoint);
    assert(classifyValidatedUbyteToFloatAffine2DByteOverlap(4,1,64,0,8,64,0,2)==AffineByteOverlapRelation.overlap);
}
static assert(classifyValidatedUbyteToFloatAffine2DByteOverlap(2,2,64,4,-1,128,-4,1)==AffineByteOverlapRelation.disjoint);
}
