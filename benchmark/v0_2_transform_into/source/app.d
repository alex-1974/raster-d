module app;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;


private enum size_t warmups = 4;
private enum size_t samples = 15;


private void require(
    bool condition,
    string message
)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    ref RasterLease!float lease
)
@system
{
    const rowElements =
        width + rowPaddingElements;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const physicalElements =
        rowElements * height;

    if (
        physicalElements
        > size_t.max / float.sizeof
    )
        return false;

    const byteLength =
        physicalElements * float.sizeof;

    void* memory =
        malloc(byteLength);

    if (memory is null)
        return false;

    auto typed =
        (cast(float*) memory)[0 .. physicalElements];

    foreach (i; 0 .. typed.length)
    {
        typed[i] =
            cast(float)(
                cast(int)(i % 251)
                - 125
            )
            * 0.03125f;
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            byteLength,
            resource
        )
    )
        return false;

    const rowStrideBytes =
        cast(ptrdiff_t)(
            rowElements * float.sizeof
        );

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            rowStrideBytes,
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const result =
        tryImportOwnedRaster!float(
            resource,
            layouts[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    return result.ok;
}


private float pointTransform(
    float value
)
@safe
pure
nothrow
@nogc
{
    return
        value * 1.0009765625f
        + 0.25f;
}


private ulong checksumFloat(
    scope RasterView!float view
)
@safe
{
    ulong hash =
        1469598103934665603UL;

    foreach (y; 0 .. view.height)
    {
        foreach (x; 0 .. view.width)
        {
            float value;

            require(
                view.trySample(
                    0,
                    x,
                    y,
                    value
                ),
                "checksum sample read failed"
            );

            union Bits
            {
                float value;
                uint bits;
            }

            Bits bits;
            bits.value =
                value;

            hash ^=
                bits.bits;

            hash *=
                1099511628211UL;
        }
    }

    return hash;
}


private long median(
    long[samples] values
)
{
    sort(values[]);
    return values[samples / 2];
}


private struct Measurement
{
    long medianNs;
    ulong checksum;
}


private Measurement benchLegacy(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!float sourceLease;
    RasterLease!float targetLease;

    require(
        makeFloatLease(
            width,
            height,
            32,
            sourceLease
        ),
        "source lease construction failed"
    );

    require(
        makeFloatLease(
            width,
            height,
            32,
            targetLease
        ),
        "target lease construction failed"
    );

    scope auto source =
        sourceLease.view();

    bool writableOk;

    scope auto target =
        targetLease.tryWritableView(
            writableOk
        );

    require(
        writableOk,
        "writable view construction failed"
    );

    RasterTransformError error;

    foreach (_; 0 .. warmups)
    {
        require(
            tryTransformRasterPlane!pointTransform(
                source,
                0,
                target,
                0,
                error
            ),
            "legacy transform failed"
        );
    }

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start =
            MonoTime.currTime;

        foreach (_; 0 .. iterations)
        {
            require(
                tryTransformRasterPlane!pointTransform(
                    source,
                    0,
                    target,
                    0,
                    error
                ),
                "legacy transform failed"
            );
        }

        times[sample] =
            (
                MonoTime.currTime
                - start
            ).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumFloat(
            targetLease.view()
        )
    );
}


private Measurement benchTransformInto(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!float sourceLease;
    RasterLease!float targetLease;

    require(
        makeFloatLease(
            width,
            height,
            32,
            sourceLease
        ),
        "source lease construction failed"
    );

    require(
        makeFloatLease(
            width,
            height,
            32,
            targetLease
        ),
        "target lease construction failed"
    );

    scope auto source =
        sourceLease.view();

    bool writableOk;

    scope auto target =
        targetLease.tryWritableView(
            writableOk
        );

    require(
        writableOk,
        "writable view construction failed"
    );

    RasterTransformError error;

    foreach (_; 0 .. warmups)
    {
        require(
            source.transformInto!pointTransform(
                0,
                target,
                0,
                error
            ),
            "transformInto failed"
        );
    }

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start =
            MonoTime.currTime;

        foreach (_; 0 .. iterations)
        {
            require(
                source.transformInto!pointTransform(
                    0,
                    target,
                    0,
                    error
                ),
                "transformInto failed"
            );
        }

        times[sample] =
            (
                MonoTime.currTime
                - start
            ).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumFloat(
            targetLease.view()
        )
    );
}


private string compilerName()
{
    version (DigitalMars)
        return "dmd";
    else version (LDC)
        return "ldc";
    else
        return "other";
}


void main(
    string[] args
)
@system
{
    const width =
        args.length >= 2
        ? args[1].to!size_t
        : 2048;

    const height =
        args.length >= 3
        ? args[2].to!size_t
        : 512;

    const iterations =
        args.length >= 4
        ? args[3].to!size_t
        : 16;

    const legacy =
        benchLegacy(
            width,
            height,
            iterations
        );

    const current =
        benchTransformInto(
            width,
            height,
            iterations
        );

    require(
        legacy.checksum
        == current.checksum,
        "legacy/new checksum mismatch"
    );

    const pixels =
        cast(double)(
            width
            * height
            * iterations
        );

    writefln(
        "transform_into_benchmark compiler=%s api=legacy width=%s height=%s iterations=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        legacy.medianNs,
        cast(double) legacy.medianNs
            / pixels,
        legacy.checksum
    );

    writefln(
        "transform_into_benchmark compiler=%s api=transformInto width=%s height=%s iterations=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        current.medianNs,
        cast(double) current.medianNs
            / pixels,
        current.checksum
    );

    writefln(
        "transform_into_ratio compiler=%s legacy_over_new=%.6f",
        compilerName(),
        cast(double) legacy.medianNs
            / cast(double) current.medianNs
    );
}
