# v0.2 benchmark-family inventory

This directory is the machine-readable coordination point for M5.1 / Issue
#115.

`families.tsv` maps the performance-relevant v0.2 processing API to retained
benchmark evidence. It is intentionally small and reviewable.

Status values:

~~~text
qualified
partial
gap
not-applicable
~~~

A family becomes `qualified` only when representative evidence records the
metadata required by `docs/V0_2_M5_BENCHMARK_FAMILIES.md`.

The inventory distinguishes public semantic work from internal execution work.
Historical executor evidence remains useful, but it does not by itself prove
that a newer public wrapper or policy layer has negligible cost.

The CI check in `tools/check_v0_2_benchmark_families.sh` validates the
inventory shape and required family IDs. It does not pretend that a text manifest
can prove performance.
