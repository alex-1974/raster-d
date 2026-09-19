# E5.4f.5c.2 production relation equivalence

This directory preserves the independent small-domain oracle used to verify
the production affine-relation implementation introduced by E5.4f.5c.2.

## Baseline

The original production verification was performed against:

`1473205c9466ccd1d8b9307bf8d461f3cc4321d4`

Commit:

`core: add checked affine same-type copy`

The probe itself is preserved byte-for-byte under `original/`.

The replay runner deliberately does **not** require that baseline commit.
Its purpose is to verify the current production implementation whenever the
affine relation code changes.

## What is verified

The probe compares the production functions directly against independent
brute-force small-domain references.

### Destination injectivity

Production:

`affine2DMappingIsInjective()`

is compared against direct enumeration of all distinct logical coordinate
pairs.

The original verification covered:

`injectivityCases=4225`

The domain includes:

- empty dimensions;
- one-sample dimensions;
- positive strides;
- negative strides;
- zero strides;
- finite mappings with and without collisions.

### Same-type affine byte overlap

Production:

`classifySameTypeAffine2DByteOverlap()`

is compared against independent enumeration of every source sample, every
target sample and their complete byte intervals.

The original verification covered:

`overlapCases=550000`

with:

- `expectedOverlapCases=234041`
- `expectedDisjointCases=315959`

The domain includes:

- empty and non-empty 2D shapes;
- positive, negative and zero row strides;
- positive, negative and zero sample strides;
- relative base-address displacement;
- sample sizes 1, 2, 3, 4 and 7 bytes.

Named cases additionally cover:

- the E5.4f bounding-envelope false positive;
- opposite traversal of the same physical sample set;
- multi-byte overlap without equal sample-start addresses;
- full machine-address separation.

## Relationship to the earlier research

This is not a replacement for the retained E5.4f research harnesses.

Those establish the underlying mathematics independently:

- finite affine destination injectivity;
- checked wide signed arithmetic;
- bounded Diophantine feasibility;
- exact affine sample-byte overlap;
- consumer-specific displacement reduction.

This harness verifies that the **composed production implementation** retains
the same semantics after those pieces were reduced and integrated.

## Relationship to copy dispatch

The probe directly verifies the mathematical production relation layer.

The complete:

`RasterView -> WritableRasterView -> checked affine copy`

integration, including failure-before-first-write semantics, remains covered by
the production unit tests in `copy_dispatch.d`.

Therefore this harness does not duplicate the entire copy dispatcher.

## Non-goals

The case counts are correctness evidence, not performance thresholds.

This harness does not establish:

- public API semantics;
- noalias;
- unique ownership;
- thread exclusivity;
- SIMD behavior;
- performance thresholds.

## Integrity

The preserved probe is immutable evidence.

Verify it with:

`sha256sum -c SHA256SUMS`

Do not refactor or format files under `original/`.

## Replay

DMD:

`experiments/e5_4f_5c2_production_equivalence/run.sh dmd`

LDC:

`experiments/e5_4f_5c2_production_equivalence/run.sh ldc2`

The replay runner:

1. verifies the preserved probe hash;
2. compiles it against the current production `affine_relation.d`;
3. executes the independent exhaustive comparison;
4. requires empty stderr;
5. requires the complete deterministic output to match the verified result.

A changed result is a correctness-review event, not an automatic indication
that the new implementation is wrong: deliberate semantic changes must first
be reconciled with the architecture and research evidence.
