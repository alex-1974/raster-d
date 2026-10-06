module app;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;


private enum size_t warmups = 4;
private enum size_t samples = 16;
private enum size_t prepIterations = 200_000;


alias Shape3x3 =
    NeighbourhoodShape!(
        3,
        3,
        1,
        1
    );


alias FixedKernel =
    FixedConvolutionKernel!(
        Shape3x3,
        float,
         0.125f, -0.250f,  0.375f,
        -0.500f,  1.250f, -0.625f,
         0.750f, -0.875f,  0.500f
    );


private struct PreparedKernel3x3
{
    double[9] coefficients;
}


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    ref RasterLease!float lease,
    out float* base,
    out size_t rowElements
)
@system
{
    base = null;
    rowElements = width + rowPaddingElements;

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

    base =
        cast(float*) memory;

    auto typed =
        base[0 .. physicalElements];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            typed[y * rowElements + x] =
                cast(float)(
                    cast(int)(
                        (y * 131 + x * 17) % 251
                    )
                    - 125
                )
                * 0.03125f;
        }
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

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(
                rowElements * float.sizeof
            ),
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


private bool makeDestinationLease(
    size_t width,
    size_t height,
    ref RasterLease!float lease,
    out float* base
)
@system
{
    size_t rowElements;

    return makeFloatLease(
        width,
        height,
        0,
        lease,
        base,
        rowElements
    );
}


private PreparedKernel3x3 prepareKernel(
    scope const(float)[9] coefficients
)
@safe
pure
nothrow
@nogc
{
    PreparedKernel3x3 result;

    foreach (i; 0 .. 9)
    {
        result.coefficients[i] =
            cast(double) coefficients[i];
    }

    return result;
}


pragma(inline, false)
private void executePreparedCanonical(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements,
    scope const PreparedKernel3x3* prepared
)
@trusted
nothrow
@nogc
{
    foreach (y; 0 .. height)
    {
        const sourceRow0 =
            sourceBase
            + y * sourceRowElements;

        const sourceRow1 =
            sourceRow0
            + sourceRowElements;

        const sourceRow2 =
            sourceRow1
            + sourceRowElements;

        auto destinationRow =
            destinationBase
            + y * destinationRowElements;

        foreach (x; 0 .. width)
        {
            double total = 0.0;

            total += cast(double) sourceRow0[x + 0] * prepared.coefficients[0];
            total += cast(double) sourceRow0[x + 1] * prepared.coefficients[1];
            total += cast(double) sourceRow0[x + 2] * prepared.coefficients[2];

            total += cast(double) sourceRow1[x + 0] * prepared.coefficients[3];
            total += cast(double) sourceRow1[x + 1] * prepared.coefficients[4];
            total += cast(double) sourceRow1[x + 2] * prepared.coefficients[5];

            total += cast(double) sourceRow2[x + 0] * prepared.coefficients[6];
            total += cast(double) sourceRow2[x + 1] * prepared.coefficients[7];
            total += cast(double) sourceRow2[x + 2] * prepared.coefficients[8];

            destinationRow[x] =
                cast(float) total;
        }
    }
}


private ulong checksum(
    scope const(float)* base,
    size_t width,
    size_t height,
    size_t rowElements
)
@trusted
nothrow
@nogc
{
    ulong hash =
        1469598103934665603UL;

    foreach (y; 0 .. height)
    {
        const row =
            base + y * rowElements;

        foreach (x; 0 .. width)
        {
            union Bits
            {
                float value;
                uint bits;
            }

            Bits bits;
            bits.value = row[x];

            hash ^=
                bits.bits;

            hash *=
                1099511628211UL;
        }
    }

    return hash;
}


private long median(long[samples] values)
{
    sort(values[]);

    return (
        values[samples / 2 - 1]
        + values[samples / 2]
    ) / 2;
}


private long timeOneShot(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start =
        MonoTime.currTime;

    foreach (iteration; 0 .. iterations)
    {
        RasterNeighbourhoodError error;

        require(
            source.convolveInto!(
                FixedKernel,
                double
            )(
                0,
                Region2D(
                    1,
                    1,
                    width,
                    height
                ),
                destination,
                0,
                error
            ),
            "one-shot convolution failed"
        );
    }

    return (
        MonoTime.currTime
        - start
    ).total!"nsecs";
}


private long timePrepared(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements,
    scope const PreparedKernel3x3* prepared,
    size_t iterations
)
@safe
{
    const start =
        MonoTime.currTime;

    foreach (iteration; 0 .. iterations)
    {
        executePreparedCanonical(
            sourceBase,
            sourceRowElements,
            width,
            height,
            destinationBase,
            destinationRowElements,
            prepared
        );
    }

    return (
        MonoTime.currTime
        - start
    ).total!"nsecs";
}


private long timePreparation(
    scope const(float)[9] coefficients,
    out ulong guard
)
@safe
{
    guard = 0;

    const start =
        MonoTime.currTime;

    foreach (iteration; 0 .. prepIterations)
    {
        const prepared =
            prepareKernel(coefficients);

        union Bits
        {
            double value;
            ulong bits;
        }

        Bits bits;
        bits.value =
            prepared.coefficients[
                iteration % 9
            ];

        guard ^=
            bits.bits
            + cast(ulong) iteration;
    }

    return (
        MonoTime.currTime
        - start
    ).total!"nsecs";
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


void main(string[] args)
@system
{
    const width =
        args.length >= 2
        ? args[1].to!size_t
        : 1024;

    const height =
        args.length >= 3
        ? args[2].to!size_t
        : 512;

    const iterations =
        args.length >= 4
        ? args[3].to!size_t
        : 8;

    RasterLease!float sourceLease;
    RasterLease!float oneShotLease;
    RasterLease!float preparedLease;

    float* sourceBase;
    float* oneShotBase;
    float* preparedBase;

    size_t sourceRowElements;

    require(
        makeFloatLease(
            width + 2,
            height + 2,
            32,
            sourceLease,
            sourceBase,
            sourceRowElements
        ),
        "source construction failed"
    );

    require(
        makeDestinationLease(
            width,
            height,
            oneShotLease,
            oneShotBase
        ),
        "one-shot destination construction failed"
    );

    require(
        makeDestinationLease(
            width,
            height,
            preparedLease,
            preparedBase
        ),
        "prepared destination construction failed"
    );

    scope auto source =
        sourceLease.view();

    bool oneShotWritableOk;

    scope auto oneShotDestination =
        oneShotLease.tryWritableView(
            oneShotWritableOk
        );

    require(
        oneShotWritableOk,
        "one-shot writable destination unavailable"
    );

    const runtimeCoefficients =
        [
             0.125f, -0.250f,  0.375f,
            -0.500f,  1.250f, -0.625f,
             0.750f, -0.875f,  0.500f
        ];

    const prepared =
        prepareKernel(
            runtimeCoefficients
        );

    RasterNeighbourhoodError qualificationError;

    require(
        source.convolveInto!(
            FixedKernel,
            double
        )(
            0,
            Region2D(
                1,
                1,
                width,
                height
            ),
            oneShotDestination,
            0,
            qualificationError
        ),
        "one-shot qualification failed"
    );

    executePreparedCanonical(
        sourceBase,
        sourceRowElements,
        width,
        height,
        preparedBase,
        width,
        &prepared
    );

    const oneShotChecksum =
        checksum(
            oneShotBase,
            width,
            height,
            width
        );

    const preparedChecksum =
        checksum(
            preparedBase,
            width,
            height,
            width
        );

    require(
        oneShotChecksum
        == preparedChecksum,
        "prepared/one-shot checksum mismatch"
    );

    foreach (warmup; 0 .. warmups)
    {
        if ((warmup & 1) == 0)
        {
            timeOneShot(
                source,
                oneShotDestination,
                width,
                height,
                1
            );

            timePrepared(
                sourceBase,
                sourceRowElements,
                width,
                height,
                preparedBase,
                width,
                &prepared,
                1
            );
        }
        else
        {
            timePrepared(
                sourceBase,
                sourceRowElements,
                width,
                height,
                preparedBase,
                width,
                &prepared,
                1
            );

            timeOneShot(
                source,
                oneShotDestination,
                width,
                height,
                1
            );
        }
    }

    long[samples] oneShotTimes;
    long[samples] preparedTimes;
    long[samples] preparationTimes;

    ulong preparationGuard;

    foreach (sample; 0 .. samples)
    {
        ulong guard;

        preparationTimes[sample] =
            timePreparation(
                runtimeCoefficients,
                guard
            );

        preparationGuard ^=
            guard;

        if ((sample & 1) == 0)
        {
            oneShotTimes[sample] =
                timeOneShot(
                    source,
                    oneShotDestination,
                    width,
                    height,
                    iterations
                );

            preparedTimes[sample] =
                timePrepared(
                    sourceBase,
                    sourceRowElements,
                    width,
                    height,
                    preparedBase,
                    width,
                    &prepared,
                    iterations
                );
        }
        else
        {
            preparedTimes[sample] =
                timePrepared(
                    sourceBase,
                    sourceRowElements,
                    width,
                    height,
                    preparedBase,
                    width,
                    &prepared,
                    iterations
                );

            oneShotTimes[sample] =
                timeOneShot(
                    source,
                    oneShotDestination,
                    width,
                    height,
                    iterations
                );
        }
    }

    const oneShotMedian =
        median(oneShotTimes);

    const preparedMedian =
        median(preparedTimes);

    const preparationBatchMedian =
        median(preparationTimes);

    const preparationNs =
        cast(double) preparationBatchMedian
        / cast(double) prepIterations;

    const logicalPixels =
        cast(double)(
            width
            * height
            * iterations
        );

    const oneShotNsPerPixel =
        cast(double) oneShotMedian
        / logicalPixels;

    const preparedNsPerPixel =
        cast(double) preparedMedian
        / logicalPixels;

    const perCallSavingsNs =
        cast(double) oneShotMedian
        - cast(double) preparedMedian;

    double breakEvenReuse =
        double.infinity;

    if (perCallSavingsNs > 0.0)
    {
        breakEvenReuse =
            preparationNs
            / perCallSavingsNs;
    }

    writefln(
        "prepared_convolution compiler=%s mode=one_shot width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        oneShotMedian,
        oneShotNsPerPixel,
        oneShotChecksum
    );

    writefln(
        "prepared_convolution compiler=%s mode=prepared width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        preparedMedian,
        preparedNsPerPixel,
        preparedChecksum
    );

    writefln(
        "prepared_convolution compiler=%s mode=prepare prep_iterations=%s batch_median_ns=%s ns_per_prepare=%.6f guard=%016x",
        compilerName(),
        prepIterations,
        preparationBatchMedian,
        preparationNs,
        preparationGuard
    );

    writefln(
        "prepared_convolution_ratio compiler=%s one_shot_over_prepared=%.6f per_call_savings_ns=%.3f break_even_reuse=%.9f",
        compilerName(),
        cast(double) oneShotMedian
            / cast(double) preparedMedian,
        perCallSavingsNs,
        breakEvenReuse
    );
}
