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

The current `origin/main` 0.4.0 release commit was reproduced on 2026-10-23
with one release run of each compiler on the local x86-64 host:

| compiler | checked ns/pixel | affine window ns/pixel | affine row ns/pixel | checksum |
|---|---:|---:|---:|---|
| DMD 2.111.0 | 37.126 | 4.641 | 3.763 | `92e280dde9dbe4d3` |
| LDC 1.42.0 | 5.738 | 1.757 | 0.855 | `92e280dde9dbe4d3` |

These are local diagnostic measurements, not a release performance gate or a
claim of parity with C++ or SIMD-specialized code. A formal qualification run
still requires the repository reference-machine harness and its recorded
environment metadata.

## Interleaved-layout finding

The benchmark uses interleaved RGB layouts. The affine window path now accepts
the separate mixed-type source/destination resources after exact byte-alias
classification. The contiguous-slice path remains intentionally unavailable
for interleaved planes because they are not flat-contiguous.
