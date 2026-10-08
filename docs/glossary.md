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

The signed byte distance between corresponding samples in adjacent logical rows.

A negative row stride is valid when the backing and descriptor make the addressed byte range valid.

## Sample stride

The signed byte distance between adjacent logical samples in one row.

## RasterLease

A retained ownership capability. It keeps the resources needed by the raster alive.

## RasterView

A read-only borrowed view. It does not own storage and must not outlive the retained lifetime it borrows from.

## WritableRasterView

A borrowed view that also proves writable backing for the represented raster.

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
