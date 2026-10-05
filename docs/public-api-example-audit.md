# Public API Example Audit

**Status:** inventory pending  
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

Generated inventory pending. The documentation workflow prints the exact public
DDox page inventory before strict per-symbol enforcement is enabled.
