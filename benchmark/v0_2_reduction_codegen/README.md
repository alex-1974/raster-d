# M5.3 reduction codegen diagnostic

This harness decomposes the remaining compiler split in the v0.2 reduction
family without changing production code.

Input signals from the retained reduction-family benchmark:

- mean: DMD about 0.985 ns/sample, LDC about 3.458 ns/sample;
- max: DMD about 4.772 ns/sample, LDC about 2.797 ns/sample;
- minMax: DMD about 5.973 ns/sample, LDC about 2.103 ns/sample.

The diagnostic measures the same padded Canonical float plane through:

- public API;
- package-internal semantic executor;
- benchmark-local exact runtime-sample-stride pointer loop;
- benchmark-local exact static sample-stride-one pointer loop.

For minMax it also measures two static-stride passes. For mean, the semantic
path is strict float-to-double row-major accumulation followed by one division.

The benchmark-local extrema loops preserve NaN propagation and signed-zero
selection. The mean loops preserve one double accumulator and exact logical
row-major addition order. No fast-math, reassociation, fixed-lane reduction,
SIMD semantic change, or threading is introduced.

The XPS runner retains six CPU-pinned processes per compiler, compiler versions,
binary hashes, complete objdump disassembly, summaries, and recursive SHA256
manifest data.
