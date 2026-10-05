# raster-d v0.1.0 documentation quality audit

Status: **IN PROGRESS**

This audit applies `docs/ddoc-style.md` to the frozen release candidate.

## Q1 — reader-first writing

Status: pending.

Public documentation must lead with consumer-visible meaning and avoid
research/history-first prose.

## Q2 — public module Ddoc

Status: pending automated inventory/remediation.

## Q3 — executable public examples

Status: pending DDox inventory.

Target:

~~~text
existing = N
add      = 0
~~~

Every required public DDox symbol page must own a compiler-checked documented
`unittest` Example.

## Q4 — internal function documentation

Status: pending automated verifier and human review.

## Q5 — decision comments

Status: pending human review.

Priority areas:

- retained ownership/lifetime;
- checked affine/address arithmetic;
- overlap/injectivity;
- strict reduction ordering;
- compiler-specific optimizer boundaries;
- SSE2 exact conversion;
- residency/materialization/block resolution.

## Q6 — generated documentation

Automated structural status: pending.

Human visual status: pending.

## Q7 — release gate

- [ ] Q1 prose review complete;
- [ ] Q2 public module Ddoc complete;
- [ ] Q3 strict per-symbol Example audit complete;
- [ ] Q4 internal Ddoc complete;
- [ ] Q5 decision-comment review complete;
- [ ] Q6 generated DDox human review complete;
- [ ] documentation workflow green on final release candidate.

Documentation quality is a release blocker.
