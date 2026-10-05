# Public API Example Audit

**Status:** inventory complete — example remediation required  
**Baseline:** raster-d 0.1 release line

## Purpose

This audit tracks executable Ddoc example coverage for the supported public
`raster-d` API.

A public DDox symbol page is complete only when a documented, compiler-checked
`unittest` renders as an **Example** on that exact page.

Examples should normally compile through:

~~~d
import raster;
~~~

## Audit families

| Family | Representative public surface | Initial state |
| --- | --- | --- |
| sample policy | `isRasterSampleType` | inventory required |
| geometry/layout | `Region2D`, `PlaneDescriptor`, `PlaneByteLayout` | inventory required |
| ownership/import | `OwnedByteResource`, import result/error/disposition, import/adopt functions | inventory required |
| retained lifetime | `RasterLease`, `RasterView`, `WritableRasterView` | inventory required |
| reduction | `trySumFloatToDouble` | inventory required |
| fill | `tryFillRasterPlane` | inventory required |
| transform | `RasterTransformError`, `tryTransformRasterPlane` | inventory required |
| neighbourhood | `RasterNeighbourhood3x3Error`, `tryApplyRasterNeighbourhood3x3` | inventory required |
| copy | `RasterCopyError`, `tryCopyRasterPlane` | inventory required |
| conversion | `UbyteToFloatConversionError`, `tryConvertUbyteToFloatPlane` | inventory required |

## Coverage policy

Dedicated examples are expected for every public DDox symbol page in the
supported 0.1 surface.

Examples must make important raster semantics visible when relevant:

- retained ownership and borrowed lifetime;
- valid and invalid `.init`;
- logical region versus physical layout;
- signed row/sample stride;
- writable-view construction;
- checked failure/no-write behavior;
- overlap/injectivity policy;
- exact `ubyte -> float` conversion;
- strict row-major reduction semantics;
- compile-time transform/kernel use.

Regression tests remain ordinary unittests rather than documentation examples.

## Completion criteria

The audit is complete when:

1. every public DDox symbol page is inventoried;
2. every page is classified;
3. no page remains classified `add`;
4. every required page is classified `existing`;
5. every `existing` page renders its own Example;
6. every rendered Example is backed by a documented compiler-checked
   `unittest`;
7. examples compile through the supported public package surface where
   practical;
8. legacy inline `Example:` blocks are rejected;
9. generated DDox and source example counts agree.

## Per-symbol classification

The first public-only DDox inventory contains **50 symbol pages**.

| DDox page | Status | Owning family |
| --- | --- | --- |
| `raster.backing.RasterLease` | add | retained lifetime |
| `raster.backing.RasterLease.tryWritableView` | add | retained lifetime |
| `raster.backing.RasterLease.view` | add | retained lifetime |
| `raster.byte_layout.PlaneByteLayout` | add | geometry/layout |
| `raster.conversion.UbyteToFloatConversionError` | add | conversion |
| `raster.conversion.tryConvertUbyteToFloatPlane` | add | conversion |
| `raster.copy.RasterCopyError` | add | copy |
| `raster.copy.tryCopyRasterPlane` | add | copy |
| `raster.descriptor.PlaneDescriptor` | add | geometry/layout |
| `raster.fill.tryFillRasterPlane` | add | fill |
| `raster.import_owned.OwnedRasterImportError` | add | ownership/import |
| `raster.import_owned.OwnedRasterImportResult` | add | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.error` | add | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.ok` | add | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.planeIndex` | add | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.resourceDisposition` | add | ownership/import |
| `raster.import_owned.OwnedRasterResourceDisposition` | add | ownership/import |
| `raster.import_owned.tryImportOwnedRaster` | add | ownership/import |
| `raster.neighbourhood.RasterNeighbourhood3x3Error` | add | neighbourhood |
| `raster.neighbourhood.tryApplyRasterNeighbourhood3x3` | add | neighbourhood |
| `raster.owned_resource.OwnedByteResource` | add | ownership/import |
| `raster.owned_resource.OwnedByteResource.byteLength` | add | ownership/import |
| `raster.owned_resource.OwnedByteResource.ownsResource` | add | ownership/import |
| `raster.owned_resource.tryAdoptMallocResource` | add | ownership/import |
| `raster.reduction.trySumFloatToDouble` | add | reduction |
| `raster.region.Region2D` | add | geometry/layout |
| `raster.region.Region2D.containsRelative` | add | geometry/layout |
| `raster.region.Region2D.empty` | add | geometry/layout |
| `raster.region.Region2D.hasRepresentableExtent` | add | geometry/layout |
| `raster.region.Region2D.tryResolveRelative` | add | geometry/layout |
| `raster.sample.isRasterSampleType` | add | sample policy |
| `raster.transform.RasterTransformError` | add | transform |
| `raster.transform.tryTransformRasterPlane` | add | transform |
| `raster.view.RasterView` | add | retained lifetime |
| `raster.view.RasterView.empty` | add | retained lifetime |
| `raster.view.RasterView.height` | add | retained lifetime |
| `raster.view.RasterView.planeCount` | add | retained lifetime |
| `raster.view.RasterView.region` | add | retained lifetime |
| `raster.view.RasterView.tryRoi` | add | retained lifetime |
| `raster.view.RasterView.trySample` | add | retained lifetime |
| `raster.view.RasterView.width` | add | retained lifetime |
| `raster.writable_view.WritableRasterView` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.empty` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.height` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.planeCount` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.region` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.tryRoi` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.trySample` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.trySetSample` | add | retained lifetime |
| `raster.writable_view.WritableRasterView.width` | add | retained lifetime |

The `add` state is intentionally strict: the page remains incomplete until its
own documented, compiler-checked `unittest` renders as an Example on that
exact DDox page.
