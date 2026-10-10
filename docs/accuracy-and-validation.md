# Accuracy and validation

raster-d treats numerical behavior as part of the API contract.

## Exact sample movement

Same-type copy preserves sample values exactly.

Fill writes the requested sample value exactly for supported sample types.

## Exact integer-to-float conversion

The released `ubyte -> float` conversion is exact because every integer in `0 .. 255` is representable in IEEE-754 binary32.

The v0.2 generic conversion family exposes an explicit `exact` policy.
Only supported type pairs may be instantiated; this is not a promise of
implicit rounding, clamping, or colour conversion. See the
[exact conversion how-to](how-to/convert-samples.md) and
[v0.2 public API contract](API_0_2.md) for supported requests and errors.

## Floating-point reduction

`trySumFloatToDouble` follows strict logical row-major order with one `double` accumulator.

This forbids tree reductions, fixed-lane reassociation, or fast-math substitutions that would change the observable arithmetic graph.
The additional typed reduction families have their own accumulator and
checked-error contracts; do not infer that all reductions use this
`float`-to-`double` order. See the
[checked sum how-to](how-to/sum-raster.md) and public Ddoc.

## Neighbourhood and convolution order

Fixed neighbourhood and convolution operations preserve the documented per-output sample order.
Missing border values are not silently synthesized by the current fixed
convolution path: the caller must supply valid neighbourhood context.
See [neighbourhood and halo processing](how-to/neighbourhood-convolution.md). Compiler-specific execution may process independent output pixels differently, but it must preserve the observable result required by the contract.

## Layout independence

Legal signed-stride and multi-plane layouts must represent the same logical samples regardless of physical placement.

Correctness tests compare semantic results across layout forms where applicable.

## Performance does not weaken semantics

Performance work may specialize source shape, layout, compiler, or ISA internally. It must not silently weaken precision, validation, failure behavior, allocation guarantees, ownership, or safety.

The primary optimized compiler is LDC. DMD remains a correctness and development baseline. Material differences are investigated and recorded rather than hidden.

## Where evidence lives

Consumer documentation states the guarantee.

Repository-level summaries and maintained benchmark harnesses explain how current production behavior is qualified.

Raw runs, large evidence archives, disposable experiments, and compiler investigations belong in `raster-d-research` or release assets.
