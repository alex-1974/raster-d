# ADR 0003: Pivot the repository from imagery-d to raster-d

## Status

Accepted.

## Context

The repository was created as `imagery-d`, with the long-term goal of becoming
a high-performance image engine for large geospatial imagery.

Research and implementation deliberately began below the image-algorithm layer.
The resulting production implementation now consists almost entirely of a
generic raster subsystem.

At the time of this decision:

- 31 of 32 production D modules are below `imagery.raster`;
- the remaining root `imagery` module contains no image-processing API;
- the implemented public surface consists of raster sample, resource,
  ownership, layout, region, view, writable-view, reduction, copy, conversion
  and retained-backing semantics;
- raster architecture, ownership, lifetime, execution, aliasing, conversion,
  region and streaming research form the majority of the repository's
  implemented technical evidence;
- the external consumer regression package consumes the raster API rather than
  an image-specific API;
- R0.3 has demonstrated decomposition-independent streamed raster execution,
  including neighbourhood/halo processing with bounded raster residency.

A final extraction-gate audit found no production image-domain semantics that
require this implementation to remain owned by an image-specific library.

The few image-domain terms found in the production raster subtree are examples
or documentation:

- interleaved RGB import test coverage;
- planar RGB import test coverage;
- an explicit statement that raster sample eligibility does not impose
  radiometric or pixel-format semantics.

The repository also contains forward-looking image-engine requirements such as
imagery mosaics, source/cache behaviour, display transforms, radiometric
processing, image enhancement and imagery benchmark corpora. Those requirements
are important, but they describe a higher layer that has not yet become the
implemented production core.

The workspace previously prohibited creating `raster-d` in parallel with
`imagery-d`. A separate raster library was permitted only when a coherent,
independently useful generic raster domain had emerged from working
`imagery-d` code.

That condition is now satisfied.

## Decision

The existing repository and its Git history will become `raster-d`.

This is a repository pivot, not a parallel reimplementation and not a
copy-and-abandon extraction.

The intended dependency direction is:

```text
future imagery-d
        |
        v
     raster-d
```

`raster-d` owns the generic raster foundation, including concepts such as:

- sample eligibility;
- raster resources and retained ownership;
- backing lifetime;
- byte and element layout;
- regions and coordinate-relative raster geometry;
- read-only and writable raster views;
- validation and write certification;
- copy and numeric conversion primitives;
- generic reductions;
- execution-layout classification;
- alias and physical-range analysis;
- generic region/dependency/streaming mechanics when promoted from research.

A future `imagery-d` will be a separate higher-level consumer and may own:

- image and pixel-format semantics;
- colour semantics;
- radiometric processing;
- imagery normalization;
- image filters and neighbourhood operators;
- mosaics and image pyramids;
- imagery-specific source/cache policy;
- image-quality analysis;
- imagery-specific geospatial metadata integration;
- benchmark imagery corpus management.

## Repository identity

The preferred migration preserves the existing Git repository history.

The current repository should therefore be renamed rather than creating a new
empty `raster-d` repository and copying the implementation into it.

The future image-engine repository should be created separately after the raster
pivot is stable.

## Module namespace

The existing module namespace:

```text
imagery.raster
imagery.raster.*
```

is transitional repository history.

The target raster-library namespace is:

```text
raster
raster.*
```

The namespace migration is a deliberate structural API change and must be
performed mechanically and validated independently from this ADR.

This ADR does not itself perform that migration.

## Documentation migration

Documentation must be classified rather than globally renamed.

Raster-specific architecture and research remain with `raster-d`.

Examples include:

- raster construction;
- raster coordinate model;
- raster execution;
- raster external import;
- raster operations;
- raster core types;
- memory/view/ownership research;
- region/dependency/streaming research;
- generic execution and performance evidence.

Mixed documents such as `DESIGN.md` and `BENCHMARK.md` must be revised
carefully.

Generic raster-engine principles remain with `raster-d`.

Forward-looking image-domain requirements should become input to the future
`imagery-d` rather than being silently redefined as raster concerns.

## Historical evidence

Historical experiment artifacts, generated assembly/LLVM files, benchmark
outputs and commit messages are evidence.

They are not to be renamed merely to remove old `imagery` wording.

For example, historical filenames containing `d-imagery` may remain unchanged
when renaming them would weaken reproducibility or disconnect recorded results
from the experiment that produced them.

Architecture documentation may explain the former naming where necessary.

## ADR history

Existing ADRs remain part of repository history.

In particular, ADR 0002 concerning non-versioned benchmark imagery is not
retroactively deleted or rewritten merely because the repository changes
scope.

Its imagery-specific policy may later be adopted by the future `imagery-d`.

## Migration constraints

The repository pivot must preserve or deliberately re-establish:

- DMD correctness;
- LDC correctness;
- compiler-floor CI;
- architecture CI;
- compile-negative lifetime coverage;
- external-consumer link closure;
- public-operation tests;
- workspace documentation consistency.

The migration must verify package identity, module identity and consumer imports
separately.

A global textual replacement is not an acceptable migration strategy.

## Consequences

The generic raster implementation obtains a name and repository boundary that
match its demonstrated responsibility.

Future image processing can depend on the raster layer without forcing DEM,
scientific-grid, GDAL-window or other non-image raster consumers to import an
image-named package.

The existing development history remains attached to the implementation that
the research actually produced.

The pivot introduces a namespace and package migration that must be planned and
tested explicitly.

The future `imagery-d` starts at the correct abstraction level rather than
reimplementing raster ownership, views, layouts and execution mechanics.

## Non-decisions

This ADR does not yet decide:

- the exact GitHub rename sequence;
- DUB registry publication or rename mechanics;
- compatibility aliases or shims;
- the exact migration commit sequence;
- when the future `imagery-d` repository is created;
- which R0.3 research types are promoted to production;
- source/cache/scheduler architecture.

Those decisions belong to the migration plan or later evidence-driven work.
