# Parallel execution qualification

This note records the resolution of issues #280 and #281 after the worker
coverage fix in #278.

## Existing policy

The public row executor already exposes the required caller policy:

- `workerLimit == 1` selects the synchronous path;
- `minimumChunk` prevents thread creation for small row ranges;
- callers own the worker limit and can reuse one operation across phases;
- callbacks are joined before the operation returns.

No automatic worker heuristic or new public scheduler is justified. The
correctness contract is more important than a machine-specific worker formula.

## Representative measurement

The imagery-shaped RGB8 two-phase benchmark was run in DMD Release on the
local host at 1024x768, with `minimumChunk=32`. All runs produced the same
checksum (`015334995c217fc3`). Values are ns/pixel for the complete two-phase
path; the serial column is the benchmark's serial implementation.

| workers | parallel two-phase | imagery serial | imagery parallel |
| ---: | ---: | ---: | ---: |
| 1 | 4.811 | 22.561 | 19.558 |
| 2 | 2.662 | 23.358 | 10.434 |
| 4 | 1.590 | 24.485 | 6.781 |
| 8 | 1.523 | 24.932 | 5.975 |

The result supports an explicit caller-selected bounded limit. It does not
support a universal automatic cap: the current host benefits from four to
eight workers for this workload, while memory-dominated kernels require their
own qualification. DMD and LDC correctness was checked separately with the
full 61-module test suite.

## Tile decision (#280)

The existing row API is intentionally not promoted to a tile API. A safe
tile writer would need a separate logical-rectangle ownership contract,
coverage validation and alias/stride proofs. No concrete consumer in this
repository currently demonstrates that the row API is insufficient, so adding
such a public primitive would increase surface area without acceptance
evidence. Irregular tile assembly remains an application-level concern until
a real consumer supplies that missing case.

## Guidance

Use the existing public wrappers with an explicit worker limit and a workload-
appropriate minimum chunk. Keep small or latency-sensitive operations at one
worker. Do not infer a limit from CPU count alone, and do not add implicit
global scheduling.
