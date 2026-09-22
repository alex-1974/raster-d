# E5.4f.5c.2 ubyte-to-float production relation equivalence

This directory preserves the independent small-domain oracle used to verify
the production affine ubyte-to-float byte-overlap relation introduced by
E5.4f.5c.2.

## Baseline

The original production verification was performed against:

`0857b3f05f014c4ab090fb59106bcade97eae1f6`

Commit:

`core: add checked affine ubyte-to-float conversion`

The probe itself is preserved byte-for-byte under `original/`.

The replay runner deliberately verifies the current production implementation,
not only the original baseline commit.

## Production relation under test

The primary function under test is:

`classifyUbyteToFloatAffine2DByteOverlap()`

The production relation handles:

- affine ubyte source mappings;
- affine float destination mappings;
- positive, negative and zero row strides;
- positive, negative and zero sample strides;
- relative source/target base addresses;
- exact physical sample-byte overlap.

For this conversion:

- each source sample occupies 1 byte;
- each destination sample occupies 4 bytes.

The retained consumer-reduction research established that physical byte
overlap therefore requires only four relevant displacement candidates:

`0, 1, 2, 3`

## Independent oracle

The preserved probe does not call the production Diophantine solver to obtain
its expected result.

Instead it independently enumerates:

1. every logical source sample;
2. every logical target sample;
3. each corresponding physical byte interval;
4. whether any source byte intersects any target float interval.

Production classification is then compared directly against that result.

## Verified domain

The deterministic small-domain verification covers:

- width: 0..2;
- height: 0..2;
- source row stride: -3..3;
- source sample stride: -3..3;
- target row stride: -3..3;
- target sample stride: -3..3;
- target-base delta relative to source: -4..4.

Total verified cases:

`ubyteToFloatCases=194481`

Expected classifications:

- `ubyteToFloatOverlapCases=56385`
- `ubyteToFloatDisjointCases=138096`

Named cases additionally verify:

- all four byte positions inside one float sample overlap;
- the byte immediately after a float sample is disjoint;
- an overlapping bounding envelope can still contain no actual sample-byte
  overlap.

## Relationship to retained research

This harness complements, rather than replaces:

`experiments/e5_4f_affine_relations/`

and:

`experiments/e5_4f_5c2_consumer_reduction/`

Those establish the general affine arithmetic and the four-candidate
ubyte-to-float reduction independently.

This harness verifies their actual composition in the current production
relation.

## Relationship to conversion dispatch

The probe directly tests the mathematical production relation.

The complete:

`RasterView!ubyte -> WritableRasterView!float -> checked affine conversion`

path remains covered by production unit tests in:

`source/raster/internal/conversion_dispatch.d`

Those tests establish operation-level behavior such as:

- destination injectivity;
- overlap rejection before the first write;
- source self-aliasing;
- negative destination strides;
- exact ubyte-to-float conversion;
- retention of the older contiguous conversion path.

## Non-goals

This harness does not establish:

- public API semantics;
- unique ownership;
- persistent noalias;
- thread exclusivity;
- SIMD behavior;
- performance thresholds.

The case counts are correctness evidence only.

## Integrity

The preserved probe is immutable evidence.

Verify it with:

`sha256sum -c SHA256SUMS`

Do not refactor or format files under `original/`.

## Replay

DMD:

`experiments/e5_4f_5c2_ubyte_float_production_equivalence/run.sh dmd`

LDC:

`experiments/e5_4f_5c2_ubyte_float_production_equivalence/run.sh ldc2`

The replay runner:

1. verifies the preserved probe hash;
2. compiles it against the current production `affine_relation.d`;
3. executes the independent comparison;
4. requires empty stderr;
5. requires deterministic output identical to the verified baseline counts.

A changed result is a correctness-review event. It must be reconciled with the
operation contract and retained research before updating this evidence.
