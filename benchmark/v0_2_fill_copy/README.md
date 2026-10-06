# v0.2 fill / copy benchmark

Purpose: qualify the M5.1 fill/copy family without weakening the production
visibility boundary.

The actual Canonical execution helpers are intentionally private production
details:

- fill uses the private Canonical row-slice executor selected by
  `raster.internal.fill_dispatch`;
- copy uses private approved row execution selected by
  `raster.internal.copy_dispatch`.

This harness therefore does not expose or duplicate those loops. It measures
the v0.2 API bridge against the already-existing semantic entry immediately
below it, while retained M3 evidence remains the executor-level evidence.

Representative workload:

- sample type: `ubyte`;
- 2048 x 512 logical samples;
- 32 elements row padding;
- unit sample stride;
- independent backing;
- allocation outside timed regions;
- 18 timed samples per process;
- six independent CPU-pinned processes per compiler.

Measured paths:

~~~text
fill:
    public_v0_2       destination.fill(...)
    public_legacy     tryFillRasterPlane(...)
    semantic_engine   tryFillRasterPlaneScalar(...)

copy:
    public_v0_2       source.copyInto(...)
    public_legacy     tryCopyRasterPlane(...)
    semantic_engine   copySameTypeRasterPlane(...)
~~~

For each operation all paths must produce the same logical checksum and leave
row padding unchanged.

The package-internal semantic engines are imported only because this benchmark
module lives in package `raster`. No public API is expanded and private
execution helpers remain private.

## Reference XPS

From repository root:

~~~bash
bash benchmark/v0_2_fill_copy/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_fill_copy/run_xps.sh CPU OUTPUT_DIR
~~~

The runner records repository head, compiler/tool versions, CPU/platform,
affinity, frequency/thermal snapshots, build logs, six independent process
outputs per compiler, summaries, SHA256SUMS and a tar.gz archive.

Hosted CI compile-smokes the harness under both baseline compilers. Absolute
hosted-runner timing is not qualification evidence.
