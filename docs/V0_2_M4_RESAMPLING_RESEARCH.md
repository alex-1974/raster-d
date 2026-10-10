# raster-d v0.2 M4.7 — generic raster resampling research

Status: research conclusion for Issue #114.

Baseline: develop adecb39ab5754ad331454bfe7c5a46623307f787.

## 1. Purpose

M4.7 researches the smallest raster-generic resampling family.
Initial candidates are nearest and bilinear.
No public resampling API is promoted by this document alone.

## 2. External reference finding

Established systems do not expose one universal resize convention.
ONNX Resize separates interpolation mode, coordinate transformation mode,
nearest tie mode and outside behavior. GDAL separately exposes nearest,
bilinear and algorithms with dataset-specific NoData semantics.

References:
- https://onnx.ai/onnx/operators/onnx__Resize.html
- https://gdal.org/en/stable/programs/gdal_raster_resize.html
- https://gdal.org/en/stable/programs/gdal_raster_overview_add.html

Conclusion: coordinate mapping is caller-visible numerical semantics, not an
implementation detail.

## 3. Three independent semantic axes

A complete resampling contract has three orthogonal choices:

1. coordinate mapping;
2. reconstruction/interpolation;
3. border behavior.

These must not be collapsed into one vague nearest or bilinear switch.

## 4. Coordinate mapping

Important candidates include half-pixel, align-corners and asymmetric mapping.

Preferred first candidate for raster resize is half-pixel / pixel-center
mapping:

    sourceCoordinate =
        (destinationCoordinate + 0.5)
        * sourceLength / destinationLength
        - 0.5

This maps destination sample centers into source sample-center coordinates
while keeping the outer discrete raster extent conceptually fixed.

Align-corners is numerically different:

    sourceCoordinate =
        destinationCoordinate
        * (sourceLength - 1)
        / (destinationLength - 1)

for destinationLength > 1.

No production API should switch between these silently.

## 5. Nearest requirements

Nearest is not fully specified by the word nearest.
It also needs explicit coordinate mapping, exact tie behavior and border
behavior.

Different ecosystems expose different half-way rules. M4.7 therefore does not
freeze a nearest tie policy without a dedicated named/policy contract.

Nearest performs no arithmetic on sample values and can therefore in principle
support every isRasterSampleType sample, including POD/static-array samples.

## 6. Bilinear requirements

Bilinear performs weighted arithmetic. The first production family should be
limited to float and double with an explicit accumulator type.

Integer bilinear interpolation is deferred because it requires explicit
fractional-result, rounding, narrowing and overflow policy.

For mapped coordinate sx,sy:

    x0 = floor(sx); x1 = x0 + 1; tx = sx - x0
    y0 = floor(sy); y1 = y0 + 1; ty = sy - y0

A candidate strict arithmetic graph is:

    top    = v00 * (1 - tx) + v10 * tx
    bottom = v01 * (1 - tx) + v11 * tx
    result = top * (1 - ty) + bottom * ty

All arithmetic occurs in the explicit accumulator type.
If Sample=float and Accumulator=double, one final double-to-float conversion
occurs after interpolation.

NaN and infinity participate through ordinary floating arithmetic.
NaN is not interpreted as NoData.

## 7. Bilinear is not an antialiasing promise

Plain 2x2 bilinear reconstruction is not an area-average or general
anti-aliasing filter for aggressive downsampling.

Area/average and higher-order reconstruction remain separate future families.

## 8. Border behavior

Half-pixel upsampling can require support outside the source sample-center
range. Border semantics are therefore part of the complete contract.

raster-d should reuse the existing generic border policies:

    RasterValidBorder
    RasterConstantBorder
    RasterClampBorder
    RasterMirrorBorder
    RasterWrapBorder

Clamp is a plausible image-like resize choice, but M4.7 does not make it a
hidden default.

## 9. Empty and degenerate dimensions

Recommended rules:

- empty destination: successful no-op after structural validation;
- non-empty destination from empty source: pre-write failure;
- single-sample source axis: nearest remains well-defined;
- bilinear with clamp may map both support samples to that single sample;
- valid-only bilinear may reject unavailable two-sample support.

## 10. Destination-oriented direction

The fundamental raster-d family should be destination-oriented.

Conceptual direction:

    source.resampleNearestInto(...)
    source.resampleBilinearInto!(Accumulator)(...)

The writable destination already carries output width and height, so Into
operations do not need a second runtime output-size object.

This lets consumers reuse buffers and control layout/allocation lifetime.

## 11. Layout, alias and write contract

All validated signed-affine source/destination layouts should remain legal.
A non-empty destination must be injective.
Actual source/destination physical overlap should be rejected before writing.
No hidden snapshot allocation should be introduced.

Canonical sample-stride-one layouts may receive internal fast paths while a
general signed-affine fallback remains available.

## 12. Prepared axis maps

Repeated resize with identical source/destination dimensions has invariant
per-axis mapping data.

Nearest can precompute destination-index to source-index tables.
Bilinear can precompute x0/x1/t and y0/y1/t tables.

This is prepared state and must remain evidence-gated:

    measure preparation cost
    measure repeated latency
    compute break-even reuse

M5 prepared-state policy is the appropriate qualification point.

## 13. raster-d ownership

raster-d should own generic discrete-raster mechanics:

- destination-oriented resize;
- explicit coordinate mapping;
- nearest selection;
- bilinear numeric interpolation;
- generic border policies;
- signed-affine layout handling;
- overlap/injectivity checks;
- allocation-free Into forms;
- evidence-gated prepared mapping tables.

## 14. imagery-d ownership

imagery-d should own semantics requiring image interpretation:

- gamma-aware / linear-light interpolation;
- colour-space conversion;
- alpha premultiplication/unpremultiplication;
- imagery-specific NoData/validity handling;
- radiometric scale/offset interpretation;
- sensor/image metadata decisions;
- image-specific filter/overview policy.

raster-d must not infer these from sample type.

## 15. Geospatial/world-coordinate boundary

CRS transformation, geotransforms, world extents and reprojection are not part
of a generic raster resize primitive.
A higher layer may map world coordinates to raster coordinates and then use
raster-d sampling/resampling machinery.

## 16. Categorical data

raster-d must not infer integer means categorical or float means continuous.
The caller chooses nearest or bilinear according to domain semantics.

## 17. Recommended future production order

Stage A — nearest Into:
- all isRasterSampleType samples;
- explicit coordinate mapping;
- explicit nearest tie rule;
- explicit border policy;
- no allocation;
- overlap rejection;
- signed-affine fallback.

Stage B — bilinear Into:
- float/double samples;
- explicit accumulator;
- explicit coordinate mapping;
- explicit border policy;
- documented arithmetic graph;
- no allocation;
- overlap rejection;
- signed-affine fallback.

Stage C — prepared axis maps only after benchmark qualification.

## 18. Deliberate non-goals

M4.7 does not promote bicubic, Lanczos, area averaging, anti-aliasing policy,
runtime-polymorphic resampler objects, geospatial reprojection, gamma-aware
interpolation, NoData-aware weighting, colour/alpha handling, hidden
allocation or hidden scheduling.

## 19. Acceptance mapping

Issue #114 asks for generic raster requirements, numerical semantics,
destination reuse opportunities and a clear raster-d versus imagery-d
boundary.

This research records all four and concludes that nearest and bilinear are
coherent raster-d candidates only when coordinate mapping and border behavior
are explicit and remain separate from image-domain semantics.
