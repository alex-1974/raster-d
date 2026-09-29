module app;

import corpus : fillDeterministic, fingerprint;
import harness : measure;
import kernels : copyScalar;

import std.stdio : writefln, writeln;

enum size_t elementCount = 1024 * 1024;
enum size_t repetitions = 9;
enum size_t warmupRounds = 2;

int main()
{
    auto source = new float[elementCount];
    auto destination = new float[elementCount];

    fillDeterministic(source, 0x5230_3500_2026_0929UL);

    const expected = fingerprint(source);

    copyScalar(source, destination);

    if (fingerprint(destination) != expected)
    {
        writeln("correctness preflight failed");
        return 1;
    }

    const samples = measure!(
        () => copyScalar(source, destination)
    )(
        repetitions,
        warmupRounds
    );

    const resultFingerprint = fingerprint(destination);

    writefln(
        "copy_scalar elements=%s median_ns=%s fingerprint=%016x",
        elementCount,
        samples.median,
        resultFingerprint
    );

    writefln(
        "raw_ns=%(%s,%)",
        samples.nanoseconds
    );

    return resultFingerprint == expected ? 0 : 1;
}
