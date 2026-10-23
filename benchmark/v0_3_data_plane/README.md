# v0.3 data-plane benchmark

Compares the checked scalar accessor path with the public `withPlanesInto`
path for a three-plane `ubyte -> float` kernel. The benchmark is diagnostic
until it is run with the repository's normal qualification runner on the
reference machine.

Run from this directory:

```bash
dub run --build=release --compiler=ldc2 --force
```

The output reports median nanoseconds per pixel and a checksum for both paths.

## Local diagnostic evidence

Five independent release processes were run on 2026-10-23 on the local
x86-64 host. The workload was 256 x 256, three planar channels and two
iterations per timing sample.

| compiler | checked range | data-plane range | checksum |
|---|---:|---:|---|
| DMD 2.111.0 | 37.325–41.086 ns/pixel | 4.547–4.915 ns/pixel | `63180c76b6201e33` |
| LDC 1.42.0 | 5.886–6.695 ns/pixel | 1.727–2.056 ns/pixel | `63180c76b6201e33` |

These are local diagnostic measurements, not a release performance gate or a
claim of parity with C++ or SIMD-specialized code. A formal qualification run
still requires the repository reference-machine harness and its recorded
environment metadata.
