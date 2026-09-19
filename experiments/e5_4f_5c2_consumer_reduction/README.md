# E5.4f.5c.2 consumer-specific affine-overlap reduction

This directory preserves the focused research probe used to justify the
consumer-specific production mapping for E5.4f.5c.2.

## Scope

The earlier E5.4f affine-relation research established exact finite affine
sample-byte overlap using bounded Diophantine reasoning and checked wide
arithmetic.

That general research deliberately permits arbitrary raster sample sizes.

Its direct byte-displacement formulation therefore has work proportional to:

`sourceSampleSize + targetSampleSize`

E5.4f.5c.2 does not need a general public affine-overlap abstraction.

The current concrete bulk-write consumers are:

- same-type raster copy;
- exact `ubyte -> float` conversion.

This probe verifies the smaller displacement sets required by those consumers.

## Verified reductions

### Same-type copy

For source and target samples of equal byte size `S`, every sample start on
either operand has one fixed residue modulo `S`.

Two samples overlap only when:

`sourceStart - targetStart`

lies in:

`[-(S - 1), S - 1]`

For one fixed residue modulo `S`, that interval contains at most two candidate
differences.

The probe verifies this reduction against independent brute-force byte-interval
overlap for multiple sample sizes.

Observed result:

`maxSameTypeCandidates=2`

### ubyte -> float conversion

For the existing exact conversion:

`sourceSampleSize = 1`

`targetSampleSize = 4`

Overlap requires:

`sourceStart - targetStart`

to be one of exactly:

`0, 1, 2, 3`

Observed result:

`ubyteToFloatCandidateCount=4`

## Verification domain

The deterministic exhaustive small-domain comparison covers:

- empty and non-empty dimensions;
- positive, negative and zero row strides;
- positive, negative and zero sample strides;
- multiple relative base displacements;
- same-type sample sizes 1, 2, 3, 4 and 7 bytes;
- the existing `ubyte -> float` sample-size pair.

The verified case counts are:

- same-type: 972405;
- `ubyte -> float`: 194481.

Both DMD 2.111.0 and LDC 1.41.0 produced identical output on the original
verification run.

## Relationship to production

This probe establishes only the consumer-specific displacement reduction.

It does not itself provide production:

- wide signed arithmetic;
- bounded Diophantine solving;
- affine destination injectivity;
- source/target overlap classification;
- writable target construction;
- copy or conversion dispatch.

Those remain separate concerns.

In particular, this result does not justify introducing a generic public
wide-integer, affine-target, alias-proof or Diophantine API.

Production E5.4f.5c.2 should map only the machinery required by the concrete
copy and conversion consumers.

## Integrity

`original/consumer_reduction.d` is retained as the verified research source.

Do not refactor or reformat it as production code.

Verify it with:

`sha256sum -c SHA256SUMS`

or use the replay runner.

## Replay

Run with DMD:

`experiments/e5_4f_5c2_consumer_reduction/run.sh dmd`

Run with LDC:

`experiments/e5_4f_5c2_consumer_reduction/run.sh ldc2`

The runner:

1. verifies the preserved source hash;
2. builds the probe with assertions enabled;
3. executes it;
4. requires empty stderr;
5. requires the complete deterministic output to match the verified result.

The case counts are deterministic correctness evidence, not performance
thresholds.
