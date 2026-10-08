# Accuracy and validation

raster-d treats numerical behavior as part of the API contract.

## Exact sample movement

Same-type copy preserves sample values exactly.

Fill writes the requested sample value exactly for supported sample types.

## Exact integer-to-float conversion

The released `ubyte -> float` conversion is exact because every integer in `0 .. 255` is representable in IEEE-754 binary32.

Generic conversion families document their own policy and failure behavior.

## Floating-point reduction

`trySumFloatToDouble` follows strict logical row-major order with one `double` accumulator.

This forbids tree reductions, fixed-lane reassociation, or fast-math substitutions that would change the observable arithmetic graph.

## Neighbourhood and convolution order

Fixed neighbourhood and convolution operations preserve the documented per-output sample order. Compiler-specific execution may process independent output pixels differently, but it must preserve the observable result required by the contract.

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
