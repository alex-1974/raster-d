# raster-d 0.3 public API audit — release candidate

**Status:** `v0.3.0` is **not published**. API review and release qualification are pending.
**Base:** `develop` commit `c7aff5d1c8ccb25e8741e940dfb69c1439a51541` (2026-10-22).
**Earlier published source contract:** [v0.2.0](API_0_2.md), frozen at `freeze/api-0.2.0`.
**v0.3 freeze checkpoints:** `freeze/feature-0.3.0` and `freeze/api-0.3.0` are **not yet created**. Do not treat this draft as an API-freeze receipt.

## Supported consumer boundary

As in v0.1 and v0.2, the supported import is:

~~~d
import raster;
~~~

The public compatibility set is the declarations re-exported by `source/raster/package.d`.
Implementation submodules do not acquire separate compatibility guarantees merely because they are present.

## Compatibility

The entire frozen v0.2 root export set (66 symbols; see [v0.2 audit](API_0_2.md)) is retained.
v0.3 adds **six** histogram-related root exports, for a candidate total of **72**.

| Added public root export | Role |
| --- | --- |
| `RasterHistogram256Error` | Explicit exact-histogram error categories |
| `RasterHistogram256Result` | Self-contained `ulong[256]` count result |
| `histogram256` | Exact single-plane `ubyte` frequencies |
| `RasterHistogramError` | Explicit interval-histogram error categories |
| `RasterHistogramResult` | In-range status plus outside-range/NaN counts |
| `histogramInto` | Caller-buffered numeric interval histogram |

Both families follow existing `RasterView` borrowing, plane index, ROI, signed-stride,
planar and interleaved contracts. The source is read-only. The operations are
`@safe nothrow @nogc`. The histogram result defaults are failures rather
than an implicit successful zero count.

## Exact 8-bit histogram

`RasterHistogram256Result histogram256(scope RasterView!ubyte source, size_t planeIndex)`

- Each value 0..255 indexes exactly one count in an owned `ulong[256]` value result.
- A valid empty selected plane succeeds with all-zero bins.
- An invalid plane or count overflow fails and publishes only zero bins.
- No mask, NoData rule, RGB/channel policy or allocation is implied.

## Configurable numeric interval histogram

`RasterHistogramResult histogramInto(T)(scope RasterView!T source, size_t planeIndex, T lower, T upper, scope ulong[] bins)`

Admitted sample types are exactly `byte`, `ubyte`, `short`, `ushort`,
`int`, `uint`, `long`, `ulong`, `float`, `double`
(as controlled by `isNumericRasterSample!T`).

- The caller owns `bins`; it is overwritten, not accumulated. It must be nonempty.
- The requested range is **closed** `[lower, upper]` with `lower < upper`.
  All but the final bin are right-exclusive; the last includes `upper`.
- In-range bin index is `min(N-1, floor((value-lower)*N/(upper-lower)))`.
- Integral placement is exact, without converting `long` or `ulong` values to `double`.
- Floating sample bounds must be finite. `NaN` is counted in `nanCount`;
  `-Infinity` and `+Infinity` in `belowRange` and `aboveRange`.
  Floating bin placement uses double arithmetic; near a bin boundary it is
  subject to ordinary floating rounding, not an exact-real guarantee.
- Error categories include `invalidPlane`, `emptyBins`, `invalidRange`,
  `countOverflow`. The entire caller buffer and result counters become zero
  on error, so a partial result cannot be mistaken for success.
- A valid empty view returns success and all-zero counters/bins.
- Both families preserve tile decomposition: counts from disjoint windows
  with identical range/bins can be combined componentwise with consumer-checked
  `ulong` overflow. No merge helper or parallel scheduler is introduced.

## Out of scope

These first public histogram APIs do not support validity masks, weighted samples,
automatic NoData semantics, sparse exact class labels, logarithmic intervals,
image colour/channel policies or automatic bucket allocation.

## Release qualification

The v0.3 release candidate must pass complete compiler/platform,
package/clean-consumer, documentation/DDox, API, numerical and publication gates.
The previous two feature PRs passed Fast DMD/LDC CI; that is **not** by itself
a full release qualification. Track sign-off in [issue #254](https://github.com/alex-1974/raster-d/issues/254)
and [v0.3 release gate](V0_3_RELEASE_GATE.md).
