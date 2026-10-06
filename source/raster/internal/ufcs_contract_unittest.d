module raster.internal.ufcs_contract_unittest;

version (unittest)
{

import raster;


/++
    Test-only point transform used to prove UFCS parsing/instantiation through
    the public root import.
+/
@safe
pure
nothrow
@nogc
private
ubyte ufcsIdentity(
    ubyte value
)
{
    return value;
}


/++
    Test-only 3 x 3 kernel used to prove UFCS parsing/instantiation through the
    public root import.
+/
@safe
pure
nothrow
@nogc
private
ubyte ufcsCenter(
    ref const(ubyte)[9] neighbourhood
)
{
    return neighbourhood[4];
}


/++
    M1.6 executable audit:
    current public free functions already support natural UFCS because their
    semantic subject is the first runtime parameter.

    Default views are sufficient here because the contract under test is API
    shape/dispatch, not successful pixel execution.
+/
@safe
unittest
{
    RasterView!ubyte source;
    WritableRasterView!ubyte destination;

    /*
     * Destination-oriented mutation: destination is the semantic subject.
     */
    assert(
        !destination.tryFillRasterPlane(
            0,
            cast(ubyte) 7
        )
    );


    /*
     * Source-oriented copy: source is the semantic subject.
     */
    RasterCopyError copyError;

    assert(
        !source.tryCopyRasterPlane(
            0,
            destination,
            0,
            copyError
        )
    );

    assert(
        copyError
        == RasterCopyError.invalidSourcePlane
    );


    /*
     * Source-oriented point transform.
     */
    RasterTransformError transformError;

    assert(
        !source.tryTransformRasterPlane!ufcsIdentity(
            0,
            destination,
            0,
            transformError
        )
    );

    assert(
        transformError
        == RasterTransformError.invalidSourcePlane
    );


    /*
     * Source-oriented neighbourhood operation.
     */
    RasterNeighbourhood3x3Error neighbourhoodError;

    assert(
        !source.tryApplyRasterNeighbourhood3x3!ufcsCenter(
            0,
            Region2D.init,
            destination,
            0,
            neighbourhoodError
        )
    );

    assert(
        neighbourhoodError
        == RasterNeighbourhood3x3Error.invalidSourcePlane
    );
}


/++
    M1.6 executable audit:
    source-oriented reduction and conversion likewise compile and dispatch
    through UFCS from the root package.
+/
@safe
unittest
{
    RasterView!float floatSource;

    double sum = 17.0;

    assert(
        !floatSource.trySumFloatToDouble(
            0,
            sum
        )
    );

    assert(sum == 0.0);


    RasterView!ubyte byteSource;
    WritableRasterView!float floatDestination;

    UbyteToFloatConversionError conversionError;

    assert(
        !byteSource.tryConvertUbyteToFloatPlane(
            0,
            floatDestination,
            0,
            conversionError
        )
    );

    assert(
        conversionError
        == UbyteToFloatConversionError.invalidSourcePlane
    );
}

} // version (unittest)
