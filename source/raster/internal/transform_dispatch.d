/++
    Invocation-local execution of validated same-type point transforms.

    M3.2b selects one generic Canonical row/pointer executor. Universal layouts
    retain the public operation's original traversal. See ADR 0011.
+/
module raster.internal.transform_dispatch;

/++
    Invokes the already compile-time-qualified point transform inside the internal execution kernel.
+/
private
T invokeApprovedPointTransform(alias transform, T)(T value)
@safe pure nothrow @nogc
{
    return transform(value);
}

/++
    Safety: the caller has validated retained backing for both non-empty views,
    matching shape, destination injectivity and exact physical disjointness.
    Both sample strides are one. Validated coordinate products and reachable
    sample addresses cover every signed row offset and every index below width.

    This trusted boundary contains only row pointer formation and bounded sample
    reads/writes. The caller-supplied transform is invoked through the same safe,
    pure, nothrow, nogc value-only contract as the reference traversal. No operand
    pointer escapes, no value expression changes, and no persistent noalias or
    ownership property is established. Indexed pointer operations require trust;
    safe row slices were measured and rejected as the production default.
+/
private
void executeCanonicalPointTransform(alias transform, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope T* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted pure nothrow @nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(width != 0 && height != 0);

    foreach (y; 0 .. height)
    {
        const sourceRow = sourceBase + cast(ptrdiff_t)y * sourceRowStride;
        auto destinationRow = destinationBase + cast(ptrdiff_t)y * destinationRowStride;

        foreach (x; 0 .. width)
            destinationRow[x] = invokeApprovedPointTransform!transform(sourceRow[x]);
    }
}

/++
    Executes a point transform only when both validated sample strides are one.
    Returns false without reading, writing or invoking transform for Universal
    layouts. The caller performs all structural and physical checks first.
+/
package(raster)
bool executeApprovedCanonicalPointTransform(alias transform, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,
    size_t width,
    size_t height,
    scope T* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride
)
@safe pure nothrow @nogc
{
    if (sourceSampleStride != 1 || destinationSampleStride != 1)
        return false;

    executeCanonicalPointTransform!transform(sourceBase, sourceRowStride,
        width, height, destinationBase, destinationRowStride);
    return true;
}

version (unittest)
{
private float mustNotRun(float value) @safe pure nothrow @nogc
{ assert(0); }

unittest
{
    // Classification decline happens before any pointer access or invocation.
    assert(!executeApprovedCanonicalPointTransform!mustNotRun(
        cast(const(float)*)null,4,2,2,2,cast(float*)null,4,1));
    assert(!executeApprovedCanonicalPointTransform!mustNotRun(
        cast(const(float)*)null,4,1,2,2,cast(float*)null,4,-1));
}
}
