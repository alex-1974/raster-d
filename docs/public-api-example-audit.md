# Public API Example Audit

**Status:** complete for the v0.2 release-candidate surface  
**Baseline:** `release/0.2` before `freeze/api-0.2.0`

## Purpose

This audit tracks executable Ddoc example coverage for the supported
`raster-d` public API.

A public DDox symbol page is complete only when a documented, compiler-checked
`unittest` renders as an **Example** on that exact page.

Examples normally compile through:

~~~d
import raster;
~~~

The aggregate import surface remains the compatibility contract. The DDox
module pages identify where those root-exported declarations are defined.

## Coverage policy

Dedicated examples are required for every public DDox symbol page in the v0.2
release surface.

Examples make caller-visible semantics concrete where relevant:

- retained ownership and borrowed lifetime;
- valid and inert `.init` states;
- logical regions versus physical layout;
- signed row/sample stride;
- writable capability;
- checked failure and no-write behavior;
- overlap and injectivity;
- exact conversion policy;
- strict reduction order and result carriers;
- compile-time transform, neighbourhood and convolution types;
- allocating versus destination-oriented operations;
- semantic border-policy vocabulary;
- ordinary and UFCS call forms.

Regression tests remain ordinary unittests unless they teach a public contract.

## Completion criteria

The audit is complete when:

1. every generated public DDox symbol page is inventoried;
2. no page remains classified `add`;
3. every `existing` page renders its own Example;
4. every rendered Example is backed by a documented compiler-checked
   `unittest`;
5. examples compile through the supported public package surface where
   practical;
6. legacy inline `Example:` blocks are rejected;
7. generated DDox, audit-row and documented-unittest counts agree.

## Per-symbol classification

The v0.2 public-only DDox inventory contains **97 symbol pages**.

| DDox page | Status | Owning family |
| --- | --- | --- |
| `raster.arithmetic_into.addInto` | existing | binary arithmetic |
| `raster.arithmetic_into.divideInto` | existing | binary arithmetic |
| `raster.arithmetic_into.multiplyInto` | existing | binary arithmetic |
| `raster.arithmetic_into.subtractInto` | existing | binary arithmetic |
| `raster.backing.RasterLease` | existing | retained lifetime |
| `raster.backing.RasterLease.tryWritableView` | existing | retained lifetime |
| `raster.backing.RasterLease.view` | existing | retained lifetime |
| `raster.border_policy.RasterBorderKind` | existing | border policy |
| `raster.border_policy.RasterClampBorder` | existing | border policy |
| `raster.border_policy.RasterConstantBorder` | existing | border policy |
| `raster.border_policy.RasterMirrorBorder` | existing | border policy |
| `raster.border_policy.RasterValidBorder` | existing | border policy |
| `raster.border_policy.RasterWrapBorder` | existing | border policy |
| `raster.byte_layout.PlaneByteLayout` | existing | geometry/layout |
| `raster.conversion.RasterConversionError` | existing | conversion |
| `raster.conversion.UbyteToFloatConversionError` | existing | conversion |
| `raster.conversion.convertRasterInto` | existing | conversion |
| `raster.conversion.tryConvertUbyteToFloatPlane` | existing | conversion |
| `raster.conversion_allocated.RasterAllocatedConversionError` | existing | allocating conversion |
| `raster.conversion_allocated.RasterAllocatedConversionResult` | existing | allocating conversion |
| `raster.conversion_allocated.tryConvertAllocated` | existing | allocating conversion |
| `raster.conversion_policy.RasterConversionPolicy` | existing | conversion policy |
| `raster.convolution.FixedConvolutionKernel` | existing | convolution |
| `raster.convolution.convolveInto` | existing | convolution |
| `raster.copy.RasterCopyError` | existing | copy |
| `raster.copy.copyInto` | existing | copy |
| `raster.copy.tryCopyRasterPlane` | existing | copy |
| `raster.descriptor.PlaneDescriptor` | existing | geometry/layout |
| `raster.fill.fill` | existing | fill |
| `raster.fill.tryFillRasterPlane` | existing | fill |
| `raster.import_owned.OwnedRasterImportError` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.error` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.ok` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.planeIndex` | existing | ownership/import |
| `raster.import_owned.OwnedRasterImportResult.resourceDisposition` | existing | ownership/import |
| `raster.import_owned.OwnedRasterResourceDisposition` | existing | ownership/import |
| `raster.import_owned.tryImportOwnedRaster` | existing | ownership/import |
| `raster.neighbourhood.RasterNeighbourhood3x3Error` | existing | neighbourhood compatibility |
| `raster.neighbourhood.tryApplyRasterNeighbourhood3x3` | existing | neighbourhood compatibility |
| `raster.neighbourhood_into.RasterNeighbourhoodError` | existing | neighbourhood |
| `raster.neighbourhood_into.applyNeighbourhoodInto` | existing | neighbourhood |
| `raster.neighbourhood_shape.NeighbourhoodShape` | existing | neighbourhood geometry |
| `raster.owned_resource.OwnedByteResource` | existing | ownership/import |
| `raster.owned_resource.OwnedByteResource.byteLength` | existing | ownership/import |
| `raster.owned_resource.OwnedByteResource.ownsResource` | existing | ownership/import |
| `raster.owned_resource.tryAdoptMallocResource` | existing | ownership/import |
| `raster.reduction.RasterExtremaError` | existing | reduction |
| `raster.reduction.RasterExtremaResult` | existing | reduction |
| `raster.reduction.RasterMeanError` | existing | reduction |
| `raster.reduction.RasterMeanResult` | existing | reduction |
| `raster.reduction.RasterMinMaxResult` | existing | reduction |
| `raster.reduction.RasterSumError` | existing | reduction |
| `raster.reduction.RasterSumResult` | existing | reduction |
| `raster.reduction.max` | existing | reduction |
| `raster.reduction.mean` | existing | reduction |
| `raster.reduction.min` | existing | reduction |
| `raster.reduction.minMax` | existing | reduction |
| `raster.reduction.sum` | existing | reduction |
| `raster.reduction.trySumFloatToDouble` | existing | reduction |
| `raster.region.Region2D` | existing | geometry/layout |
| `raster.region.Region2D.containsRelative` | existing | geometry/layout |
| `raster.region.Region2D.empty` | existing | geometry/layout |
| `raster.region.Region2D.hasRepresentableExtent` | existing | geometry/layout |
| `raster.region.Region2D.tryResolveRelative` | existing | geometry/layout |
| `raster.sample.isExactConvertible` | existing | sample policy |
| `raster.sample.isNumericRasterSample` | existing | sample policy |
| `raster.sample.isRasterSampleType` | existing | sample policy |
| `raster.transform.RasterTransformError` | existing | transform compatibility |
| `raster.transform.tryTransformRasterPlane` | existing | transform compatibility |
| `raster.transform_allocated.RasterAllocatedTransformError` | existing | allocating transform |
| `raster.transform_allocated.RasterAllocatedTransformResult` | existing | allocating transform |
| `raster.transform_allocated.RasterAllocatedTransformResult.error` | existing | allocating transform |
| `raster.transform_allocated.RasterAllocatedTransformResult.lease` | existing | allocating transform |
| `raster.transform_allocated.RasterAllocatedTransformResult.ok` | existing | allocating transform |
| `raster.transform_allocated.RasterAllocatedTransformResult.transformError` | existing | allocating transform |
| `raster.transform_allocated.tryTransformAllocated` | existing | allocating transform |
| `raster.transform_into.transformInto` | existing | transform |
| `raster.view.RasterView` | existing | read-only view |
| `raster.view.RasterView.empty` | existing | read-only view |
| `raster.view.RasterView.height` | existing | read-only view |
| `raster.view.RasterView.planeCount` | existing | read-only view |
| `raster.view.RasterView.region` | existing | read-only view |
| `raster.view.RasterView.tryRoi` | existing | read-only view |
| `raster.view.RasterView.trySample` | existing | read-only view |
| `raster.view.RasterView.width` | existing | read-only view |
| `raster.writable_view.WritableRasterView` | existing | writable view |
| `raster.writable_view.WritableRasterView.empty` | existing | writable view |
| `raster.writable_view.WritableRasterView.height` | existing | writable view |
| `raster.writable_view.WritableRasterView.planeCount` | existing | writable view |
| `raster.writable_view.WritableRasterView.region` | existing | writable view |
| `raster.writable_view.WritableRasterView.tryRoi` | existing | writable view |
| `raster.writable_view.WritableRasterView.trySample` | existing | writable view |
| `raster.writable_view.WritableRasterView.trySetSample` | existing | writable view |
| `raster.writable_view.WritableRasterView.width` | existing | writable view |
| `raster.zip_transform_into.RasterZipTransformError` | existing | binary transform |
| `raster.zip_transform_into.zipTransformInto` | existing | binary transform |

All 97 pages must render their own Example. Every Example is backed by a
documented, compiler-checked `unittest`. The source may contain additional
documented tests for a page or family, so the documented-unittest count may be
greater than the DDox page count but must never be smaller.
