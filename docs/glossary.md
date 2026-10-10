# Glossary

## Backing

Physical storage that contains raster bytes. A raster may describe one or more backing resources.

## Descriptor

Metadata that maps a logical plane to bytes in retained backing.

## Logical region

The raster-space rectangle visible to the caller. Logical coordinates are not raw byte offsets.

## Plane

One raster sample field described by its own byte layout. A raster may contain multiple planes.

## Row stride

The signed distance between corresponding samples in adjacent rows. Public `PlaneByteLayout` expresses it in **bytes**; validated internal `PlaneDescriptor` expresses it in **sample elements**.

A negative row stride is valid when the retained backing and validated descriptor keep every addressed sample in bounds.

## Sample stride

The signed distance between adjacent logical samples in one row. The unit is **bytes** for `PlaneByteLayout` and **sample elements** for the internal `PlaneDescriptor`.

## RasterLease

A retained ownership capability. Copies retain the same backing, and its physical resources are released when the last owning lease releases them. The current reference count is non-atomic; concurrent manipulation of shared lease handles is not an advertised guarantee.

## RasterView

A read-only borrowed view. It does not own pixel or descriptor storage and must not outlive the retained lifetime it borrows from. `scope` and `return` annotations express the intended borrowing contract; ordinary D compiler mode does not reject every escape that explicit DIP1000 mode rejects.

## WritableRasterView

A borrowed view that also proves writable backing for the represented raster. Writable permission does not imply unique ownership, non-aliasing, non-overlap, or thread exclusivity.

## Region of interest (ROI)

A logical subregion represented without copying sample data.

## Canonical layout

An internal execution classification for common compact positive-stride layouts. It is not a separate public raster semantic.

## Materialization

Filling caller-owned destination storage for a requested raster region from a source capability.

## Retained store

Bounded internal raster residency that can reuse already materialized blocks. It is not a public scheduler or worker pool.

## Neighbourhood

A fixed spatial context around an output position, such as a 3 x 3 or 5 x 3 sample window.

## Convolution

A neighbourhood operation that combines samples with fixed coefficients in a defined order.
