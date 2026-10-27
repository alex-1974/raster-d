# raster-d v0.5.4 release notes

`raster-d` v0.5.4 is a patch release that corrects the external
imagery-shaped data-plane benchmark and documents its workload semantics.

## Benchmark correction

- mask-filtered worker-local 65,536-bin histograms;
- deterministic integer luma mapping and histogram reduction;
- documented 75th-percentile nearest-rank threshold selection;
- serial and parallel implementations of the complete workload;
- independent reference-fixture validation and serial/parallel checksum
  comparison.

The public `raster-d` API is unchanged. The benchmark remains generic; RGB,
mask and colour semantics belong to downstream consumers.

## Qualification

- DMD and LDC Release builds pass at 1024x768 and 1920x1080;
- the corrected benchmark reports comparable serial and parallel timings;
- the v0.5.3 imagery-shaped benchmark defect is resolved by PR #275.
