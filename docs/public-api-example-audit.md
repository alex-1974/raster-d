# Public API Example Audit

**Status:** complete  
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
| `raster.backing.RasterLease` | existing | retained lifetime |
| `raster.backing.RasterLease.tryWritableView` | existing | retained lifetime |
| `raster.backing.RasterLease.view` | existing | retained lifetime |
| `raster.byte_layout.PlaneByteLayout` | existing | geometry/layout |
| `raster.conversion.UbyteToFloatConversionError` | existing | conversion |
| `raster.conversion.tryConvertUbyteToFloatPlane` | existing | conversion |
| `raster.copy.RasterCopyError` | existing | copy |
| `raster.copy.tryCopyRasterPlane` | existing | copy |
| `raster.descriptor.PlaneDescriptor` | existing | geometry/layout |
| `raster.fill.tryFillRasterPlane` | existing | fill |
| `raster.import_owned.OwnedRasterImportError` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.error` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.ok` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.planeIndex` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.resourceDisposition` | existing | ownership/import |
| `raster.import_owned.OwnedRasterResourceDisposition` | existing | ownership/import |
| `raster.import_owned.tryImportOwnedRaster` | existing | ownership/import |
| `raster.neighbourhood.RasterNeighbourhood3x3Error` | existing | neighbourhood |
| `raster.neighbourhood.tryApplyRasterNeighbourhood3x3` | existing | neighbourhood |
| `raster.owned_resource.OwnedByteResource` | existing | ownership/import |
| `raster.owned_resource.OwnedByteResource.byteLength` | existing | ownership/import |
| `raster.owned_resource.OwnedByteResource.ownsResource` | existing | ownership/import |
| `raster.owned_resource.tryAdoptMallocResource` | existing | ownership/import |
| `raster.reduction.trySumFloatToDouble` | existing | reduction |
| `raster.region.Region2D` | existing | geometry/layout |
| `raster.region.Region2D.containsRelative` | existing | geometry/layout |
| `raster.region.Region2D.empty` | existing | geometry/layout |
| `raster.region.Region2D.hasRepresentableExtent` | existing | geometry/layout |
| `raster.region.Region2D.tryResolveRelative` | existing | geometry/layout |
| `raster.sample.isRasterSampleType` | existing | sample policy |
| `raster.transform.RasterTransformError` | existing | transform |
| `raster.transform.tryTransformRasterPlane` | existing | transform |
| `raster.view.RasterView` | existing | retained lifetime |
| `raster.view.RasterView.empty` | existing | retained lifetime |
| `raster.view.RasterView.height` | existing | retained lifetime |
| `raster.view.RasterView.planeCount` | existing | retained lifetime |
| `raster.view.RasterView.region` | existing | retained lifetime |
| `raster.view.RasterView.tryRoi` | existing | retained lifetime |
| `raster.view.RasterView.trySample` | existing | retained lifetime |
| `raster.view.RasterView.width` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.empty` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.height` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.planeCount` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.region` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.tryRoi` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.trySample` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.trySetSample` | existing | retained lifetime |
| `raster.writable_view.WritableRasterView.width` | existing | retained lifetime |

All 50 inventoried pages now render their own documented, compiler-checked `unittest` as an Example. The strict verifier requires the rendered-page count, audit `existing` count, and documented-unittest count to remain identical.
