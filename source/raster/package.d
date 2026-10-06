/++
    Core raster geometry and physical layout metadata.

    The raster package keeps semantic raster types independent from any
    particular execution substrate such as Mir.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-05
+/
module raster;

public import raster.sample :
    isRasterSampleType;

public import raster.owned_resource :
    OwnedByteResource,
    tryAdoptMallocResource;

public import raster.byte_layout :
    PlaneByteLayout;

public import raster.import_owned :
    OwnedRasterImportError,
    OwnedRasterImportResult,
    OwnedRasterResourceDisposition,
    tryImportOwnedRaster;

public import raster.descriptor :
    PlaneDescriptor;

public import raster.region :
    Region2D;

public import raster.view :
    RasterView;

public import raster.writable_view :
    WritableRasterView;

public import raster.reduction :
    RasterSumError,
    RasterSumResult,
    RasterExtremaError,
    RasterExtremaResult,
    RasterMinMaxResult,
    RasterMeanError,
    RasterMeanResult,
    sum,
    min,
    max,
    minMax,
    mean,
    trySumFloatToDouble;

public import raster.fill :
    tryFillRasterPlane,
    fill;

public import raster.transform :
    RasterTransformError,
    tryTransformRasterPlane;

public import raster.transform_into :
    transformInto;

public import raster.zip_transform_into :
    RasterZipTransformError,
    zipTransformInto;

public import raster.arithmetic_into :
    addInto,
    subtractInto,
    multiplyInto,
    divideInto;

public import raster.transform_allocated :
    RasterAllocatedTransformError,
    RasterAllocatedTransformResult,
    tryTransformAllocated;

public import raster.neighbourhood :
    RasterNeighbourhood3x3Error,
    tryApplyRasterNeighbourhood3x3;

public import raster.copy :
    RasterCopyError,
    tryCopyRasterPlane,
    copyInto;

public import raster.conversion_policy :
    RasterConversionPolicy;

public import raster.conversion :
    RasterConversionError,
    UbyteToFloatConversionError,
    convertRasterInto,
    tryConvertUbyteToFloatPlane;

public import raster.conversion_allocated :
    RasterAllocatedConversionError,
    RasterAllocatedConversionResult,
    tryConvertAllocated;

public import raster.backing :
    RasterLease;
