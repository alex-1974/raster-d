/++
    Core raster geometry and physical layout metadata.

    The raster package keeps semantic raster types independent from any
    particular execution substrate such as Mir.
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
    trySumFloatToDouble;

public import raster.copy :
    RasterCopyError,
    tryCopyRasterPlane;

public import raster.conversion :
    UbyteToFloatConversionError,
    tryConvertUbyteToFloatPlane;

public import raster.backing :
    RasterLease;
