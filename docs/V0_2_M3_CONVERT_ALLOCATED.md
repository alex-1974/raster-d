# raster-d v0.2 M3.7 — allocating conversion convenience

Status: implementation candidate for Issue #106.

Baseline:

~~~text
develop
64955951008129f9a0e7602e7f660455cdaa3624
~~~

## 1. Public API

v0.2 adds:

~~~d
RasterAllocatedConversionResult!To tryConvertAllocated(
    To,
    RasterConversionPolicy Policy = RasterConversionPolicy.exact,
    From
)(
    scope RasterView!From source,
    size_t sourcePlaneIndex
);
~~~

UFCS:

~~~d
auto result = source.tryConvertAllocated!float(sourcePlaneIndex);
~~~

Explicit policy spelling:

~~~d
auto result = source.tryConvertAllocated!(
    float,
    RasterConversionPolicy.exact
)(sourcePlaneIndex);
~~~

## 2. Purpose

This is an allocating convenience wrapper over the destination-oriented
convertRasterInto family.

It is not a second conversion engine.

The execution sequence is:

~~~text
validate source plane
    -> allocate compact retained To raster
    -> obtain writable destination view
    -> convertRasterInto!(To, Policy)
    -> return retained RasterLease!To
~~~

Callers that already own or want to reuse destination storage should continue
to use convertRasterInto.

## 3. Allocation is explicit

tryConvertAllocated allocates/materializes output storage by design.

Successful non-empty output uses:

~~~text
one retained malloc-compatible pixel allocation
one logical plane
resident origin 0,0
sample stride 1
row stride width
sample type To
~~~

The result therefore owns storage independently from the source.

Allocation is visible in the operation name, result type and documentation.

## 4. Transitional owner

The successful result currently carries RasterLease!To.

This matches the existing v0.2 allocating-transform convenience.

RasterLease remains the production retained owner until the designed Raster!T
owner is promoted. No second owner/backing architecture is introduced.

## 5. Shared compact allocation

M3.7 moves the compact one-plane allocation helper previously private to
transform_allocated into raster.internal.compact_allocation.

Both tryTransformAllocated and tryConvertAllocated now use the same
package-internal retained allocation path.

This is an implementation refactor only. The existing public
tryTransformAllocated contract is unchanged.

## 6. Result carrier

RasterAllocatedConversionResult!To exposes:

~~~text
ok
error
conversionError
lease()
~~~

On success, lease() returns an O(1) retained owner copy.
On failure, lease() returns RasterLease!To.init.

## 7. High-level failure model

~~~d
enum RasterAllocatedConversionError : ubyte
{
    none,
    invalidSourcePlane,
    sizeOverflow,
    allocationFailed,
    backingConstructionFailed,
    writableDestinationUnavailable,
    conversionFailed,
    internalFailure
}
~~~

conversionError is meaningful only when error == conversionFailed and carries
the underlying RasterConversionError.

## 8. Source validation before allocation

An invalid source plane fails before allocating output storage.

## 9. Size and allocation failure

The shared compact allocator checks width * height, sampleCount * To.sizeof,
width * To.sizeof, and ptrdiff_t-compatible row/sample strides before
allocation.

## 10. Empty geometry

A valid zero-area source succeeds without pixel allocation.

The result contains a genuine retained metadata-only one-plane RasterLease!To
with the same width/height as source. convertRasterInto then executes its
ordinary matching-empty no-op semantic.

## 11. Conversion semantics

All sample semantics come from convertRasterInto!(To, Policy). Therefore
allocating conversion inherits exact-policy type constraints, logical value
conversion, layout independence, floating NaN/infinity behavior for legal
exact pairs, and structural failure semantics.

There is no second conversion loop in conversion_allocated.d.

## 12. Alias behavior

Allocated non-empty output uses newly owned storage and therefore cannot alias
the source pixel resource. The wrapper still calls convertRasterInto rather
than bypassing its contract.

## 13. Destination-oriented API remains primary

tryConvertAllocated is convenience/materialization. convertRasterInto remains
the fundamental API for consumers that reuse destination storage or require
custom layouts.

## 14. Attributes

tryConvertAllocated is @safe but may allocate and therefore is not @nogc.
The underlying conversion remains @safe nothrow @nogc.

## 15. Tests

Coverage includes signed-stride source -> compact widened output, ubyte ->
float through the qualified exact production path, independently writable
output, zero-area metadata-only output, invalid source plane before
allocation, and explicit exact policy spelling.

Existing transform-allocated tests simultaneously qualify the shared compact
allocation refactor on DMD and LDC.

## 16. Acceptance mapping

Issue #106 requires allocation to be documented, no duplicate conversion
engine, destination-oriented reuse to remain available, and semantics to match
the corresponding Into operation.

The implementation satisfies these by calling convertRasterInto directly and
sharing the established retained compact-allocation path.

The PR is ready to close #106 once both Fast CI gates are green.
