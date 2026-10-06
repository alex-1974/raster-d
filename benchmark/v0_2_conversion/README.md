# v0.2 conversion benchmark

Purpose: qualify the M5.1 conversion family without exposing private production
executors or introducing a second conversion engine.

The harness separates three questions.

~~~text
ubyte -> float:
    public_generic
        convertRasterInto!float

    public_specialized
        tryConvertUbyteToFloatPlane

    semantic_engine
        convertExactRasterPlane!(ubyte, float)

ushort -> float:
    public_generic
        convertRasterInto!float

    semantic_engine
        convertExactRasterPlane!(ushort, float)

allocated ushort -> float:
    public_allocated
        tryConvertAllocated!float

    explicit_allocate_convert
        allocateCompactRaster!float
        -> writable view
        -> convertRasterInto!float
~~~

The ubyte control isolates the new generic policy/API spelling from the
already-qualified compiler-specialized production path. The ushort control
exercises the generic exact-policy engine rather than the historical ubyte
special case. The allocated comparison isolates the convenience wrapper from
the same explicit allocation + destination-oriented conversion sequence.

Private numeric executors remain private. M3.5 / ADR 0013 / ADR 0014 remain
the executor/preflight/code-generation evidence.

Representative workload:

- 2048 x 512 logical samples;
- 32 elements row padding for destination-oriented paths;
- unit sample stride;
- independent source/destination backing;
- all allocation outside timed regions except the two explicitly allocating
  paths;
- 6 warmups;
- 18 rotating timed samples;
- six independent CPU-pinned processes per compiler.

Every destination-oriented path must produce the same checksum within its type
pair and leave row padding unchanged. Allocating paths are semantically checked
before timing.

## Reference XPS

From repository root:

~~~bash
bash benchmark/v0_2_conversion/run_xps.sh
~~~

Optional:

~~~bash
bash benchmark/v0_2_conversion/run_xps.sh CPU OUTPUT_DIR
~~~

The runner records repository head, compiler/tool versions, CPU/platform,
affinity, frequency/thermal snapshots, build logs, six independent process
outputs per compiler, summaries, SHA256SUMS and a tar.gz archive.

Hosted CI compile-smokes the harness under both baseline compilers. Hosted
runner timings are not qualification evidence.
