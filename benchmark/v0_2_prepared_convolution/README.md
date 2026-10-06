# v0.2 prepared convolution qualification research

Issue: #113 — qualify whether prepared convolution state deserves production.

This benchmark deliberately does **not** add a public prepared-state type.

It compares:

- production one-shot fixed 3x3 convolution through `convolveInto`;
- a research-only prepared candidate whose float coefficients are converted once
  to double and whose repeated path receives already validated Canonical raw
  pointers.

The prepared candidate is intentionally advantaged:

- no public API validation inside the repeated loop;
- no shape/alias/injectivity preflight inside the repeated loop;
- no coefficient conversion inside the repeated loop;
- direct fixed 3x3 Canonical pointer execution.

Therefore:

- if prepared does **not** materially outperform one-shot, production prepared
  state is not justified;
- if prepared does outperform one-shot, the result is only evidence to continue
  research, because part of the gain may come from bypassed structural
  validation rather than preparation itself.

Measured series:

- repeated one-shot latency;
- preparation cost;
- prepared repeated latency;
- approximate break-even reuse count.

Both paths must produce identical checksums.

## Reference XPS

From the repository root on a commit that contains the merged qualification
harness (normally current `develop`):

    git switch develop
    git pull --ff-only origin develop
    bash benchmark/v0_2_prepared_convolution/run_xps.sh

Optional:

    bash benchmark/v0_2_prepared_convolution/run_xps.sh CPU OUTPUT_DIR

Defaults:

- CPU = 0
- output = /tmp/raster-v0.2-prepared-convolution-<timestamp>

The runner builds DMD and LDC release binaries, pins six independent processes
per compiler, records thermal/frequency snapshots, summarizes medians/ranges,
writes SHA256SUMS, and creates a tar.gz evidence archive.

GitHub-hosted CI is compile/correctness smoke only and is not accepted as the
performance qualification for #113.
