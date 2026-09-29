module app;

import affine_bench : runAffineMatrix;
import corpus : fillDeterministic, fingerprint;
import harness : measurePair;
import kernels :
    copyScalar,
    copySlice,
    fillScalar,
    fillSlice;

import raster.internal.r0_5_abstraction_bench :
    copyCheckedContiguous1D,
    copyMirContiguous1D,
    makeContiguousCopyFixture;

import std.stdio : writefln, writeln;

enum size_t elementCount = 1024 * 1024;
enum size_t repetitions =  nineRepetitions;
enum size_t warmupRounds = 2;
enum size_t nineRepetitions = 9;
enum float fillValue = 0.375f;

private void printPair(
    string family,
    string firstLabel,
    string secondLabel,
    const(long)[] firstRaw,
    const(long)[] secondRaw,
    long firstMedian,
    long secondMedian
)
{
    writefln(
        "%s %s_median_ns=%s %s_median_ns=%s ratio_second_over_first=%.6f",
        family,
        firstLabel,
        firstMedian,
        secondLabel,
        secondMedian,
        cast(double) secondMedian / cast(double) firstMedian
    );

    writefln(
        "%s %s_raw_ns=%(%s,%)",
        family,
        firstLabel,
        firstRaw
    );

    writefln(
        "%s %s_raw_ns=%(%s,%)",
        family,
        secondLabel,
        secondRaw
    );
}

int main()
{
    auto source = new float[elementCount];
    auto destination = new float[elementCount];

    fillDeterministic(source, 0x5230_3500_2026_0929UL);
    const sourceFingerprint = fingerprint(source);

    copyScalar(source, destination);
    if (fingerprint(destination) != sourceFingerprint)
    {
        writeln("copy_scalar correctness preflight failed");
        return 1;
    }

    copySlice(source, destination);
    if (fingerprint(destination) != sourceFingerprint)
    {
        writeln("copy_slice correctness preflight failed");
        return 1;
    }

    fillScalar(destination, fillValue);
    const fillFingerprint = fingerprint(destination);

    fillSlice(destination, fillValue);
    if (fingerprint(destination) != fillFingerprint)
    {
        writeln("fill_slice correctness preflight failed");
        return 1;
    }

    const copySamples = measurePair!(
        () => copyScalar(source, destination),
        () => copySlice(source, destination)
    )(
        repetitions,
        warmupRounds
    );

    if (fingerprint(destination) != sourceFingerprint)
    {
        writeln("copy benchmark postflight failed");
        return 1;
    }

    printPair(
        "copy",
        "scalar",
        "slice",
        copySamples.first.nanoseconds,
        copySamples.second.nanoseconds,
        copySamples.first.median,
        copySamples.second.median
    );

    enum size_t rasterWidth = 1024;
    enum size_t rasterHeight = elementCount / rasterWidth;

    auto rasterFixture =
        makeContiguousCopyFixture(
            source,
            destination,
            rasterWidth,
            rasterHeight
        );

    if (!copyMirContiguous1D(
        rasterFixture.source,
        rasterFixture.target
    ))
    {
        writeln("raster Mir contiguous1D preflight failed");
        return 1;
    }

    if (fingerprint(destination) != sourceFingerprint)
    {
        writeln("raster Mir contiguous1D fingerprint failed");
        return 1;
    }

    if (!copyCheckedContiguous1D(
        rasterFixture.source,
        rasterFixture.target
    ))
    {
        writeln("raster checked contiguous1D preflight failed");
        return 1;
    }

    if (fingerprint(destination) != sourceFingerprint)
    {
        writeln("raster checked contiguous1D fingerprint failed");
        return 1;
    }

    const abstractionSamples = measurePair!(
        () => copyMirContiguous1D(
            rasterFixture.source,
            rasterFixture.target
        ),
        () => copyCheckedContiguous1D(
            rasterFixture.source,
            rasterFixture.target
        )
    )(
        repetitions,
        warmupRounds
    );

    if (fingerprint(destination) != sourceFingerprint)
    {
        writeln("raster abstraction benchmark postflight failed");
        return 1;
    }

    printPair(
        "raster_copy",
        "mir_contiguous1d",
        "checked_contiguous1d",
        abstractionSamples.first.nanoseconds,
        abstractionSamples.second.nanoseconds,
        abstractionSamples.first.median,
        abstractionSamples.second.median
    );

    const fillSamples = measurePair!(
        () => fillScalar(destination, fillValue),
        () => fillSlice(destination, fillValue)
    )(
        repetitions,
        warmupRounds
    );

    const finalFingerprint = fingerprint(destination);
    if (finalFingerprint != fillFingerprint)
    {
        writeln("fill benchmark postflight failed");
        return 1;
    }

    printPair(
        "fill",
        "scalar",
        "slice",
        fillSamples.first.nanoseconds,
        fillSamples.second.nanoseconds,
        fillSamples.first.median,
        fillSamples.second.median
    );

    writefln(
        "elements=%s source_fingerprint=%016x fill_fingerprint=%016x",
        elementCount,
        sourceFingerprint,
        finalFingerprint
    );

    if (runAffineMatrix() != 0)
        return 1;

    return 0;
}
