# raster-d v0.5.5 release notes

`raster-d` v0.5.5 is a patch release that makes bounded parallel row
execution safe for downstream consumers and records the resulting performance
guidance.

## Fixed

- each parallel callback now receives its own stable worker index and exact,
  disjoint row interval;
- repeated phases remain joined and ordered, including callback failure paths;
- deterministic coverage tests exercise 2, 4 and 8 workers with short final
  chunks under DMD and LDC.

## Qualification

- all required Release Gate, Compiler Floor, API documentation, archive
  consumer and Fast CI checks pass;
- caller-selected worker limits remain the supported policy;
- no new tile scheduler or automatic machine-specific worker heuristic was
  added without a concrete consumer and safety evidence.

The public raster API and numerical behavior are unchanged.
