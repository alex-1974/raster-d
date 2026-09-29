module neighbourhood_versioning_guard_probe;

import std.stdio : writefln;

/*
 * R0.5f diagnostic only.
 *
 * Report the concrete source/destination ranges used by the benchmark and
 * compare observed timing with the loop-versioning assembly. This deliberately
 * does not duplicate LLVM's optimizer-generated guard as a production
 * contract.
 */
void reportVersioningGeometry(
    scope const(float)[] source,
    scope float[] destination,
    size_t pitch
)
@trusted
{
    const srcBegin = cast(size_t) source.ptr;
    const srcEnd = cast(size_t)(source.ptr + source.length);
    const dstBegin = cast(size_t) destination.ptr;
    const dstEnd = cast(size_t)(destination.ptr + destination.length);

    writefln(
        "versioning_geometry src_begin=0x%x src_end=0x%x dst_begin=0x%x dst_end=0x%x pitch=%s disjoint=%s",
        srcBegin, srcEnd, dstBegin, dstEnd, pitch,
        srcEnd <= dstBegin || dstEnd <= srcBegin
    );
}
