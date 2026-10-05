# raster-d Research

Experimental research, benchmark evidence, compiler investigations,
code-generation evidence and disposable prototypes are maintained separately
in the raster-d-research repository:

https://github.com/alex-1974/raster-d-research

The production raster-d repository retains accepted source code, tests,
architecture contracts and architecture decision records.

Moving research evidence to the separate repository does not change the
history or provenance of production decisions derived from that evidence.

## Initial research snapshot

Source repository: alex-1974/raster-d

Source commit:
91fd96dceb70886f2cf33f7af8a6cce30f78168a

Initial research snapshot commit:
dee2e0097a335139362d936b4c8bd47c2d21af17

Verified snapshot:

- 228 files
- 2840033 bytes
- identical relative paths
- identical Git file modes
- identical Git blob identities

Additional provenance is recorded in PROVENANCE.md in raster-d-research.

## Repository boundary

raster-d contains:

- production source and public contracts
- production correctness and consumer tests
- architecture decision records
- accepted architecture documentation
- production CI and release configuration

raster-d-research contains:

- experiments and disposable prototypes
- benchmark runs and raw performance evidence
- compiler and code-generation investigations
- research reports
- retained evidence for reproducing or revisiting production decisions

Research findings enter raster-d through an explicit promotion step.
Supporting experimental evidence remains in raster-d-research.

Historical raster-d commits remain part of the raster-d Git history.
