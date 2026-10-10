# raster-d Documentation Style Guide

**Status:** Release standard  
**Scope:** Public Ddoc, internal code documentation, examples, and explanatory comments

## 1. Purpose

Documentation is part of the product.

A consumer should be able to use the supported public raster API without
reading its implementation. A maintainer should be able to change an internal
execution strategy without first reconstructing the ownership, lifetime,
layout, numerical, or performance rationale from source.

The standard has four goals:

1. explain the public contract to the consumer;
2. show realistic use through compiler-checked DDox examples;
3. explain non-obvious internal functions and invariants to maintainers;
4. preserve the reasons behind important implementation decisions.

## 2. Writing standard

All documentation is written in English. William Zinsser's *On Writing
Well* is the editorial model for ordinary prose: clarity, simplicity, brevity,
and direct language. Technical precision still wins when a contract needs an
exact term.

Write for the reader, not for the implementation author:

- state caller-visible meaning before mechanism;
- prefer short, concrete words and active verbs;
- omit words that do not change the meaning;
- avoid noun stacks when a verb says the same thing more clearly;
- let one sentence do one job;
- remove throat-clearing phrases and repeated conclusions;
- use positive statements when they are as precise as negative ones;
- explain one idea at a time;
- use raster terminology only when it is part of the contract;
- distinguish logical coordinates, descriptor coordinates, resident backing,
  and execution layout;
- do not make a consumer learn repository history to understand an API.

Engineering evidence may be denser than a tutorial, but it should still state
the question, evidence, and decision directly. Repetition is not a substitute
for confidence.

Good consumer documentation answers:

> What does this let me represent or do, what do I pass in, what remains alive,
> what do I get back, and what can go wrong?

Historical research and implementation selection belong in ADRs, benchmarks,
validation records, and decision comments.

## 3. Public Ddoc contract

Every supported public symbol reachable through:

~~~d
import raster;
~~~

must have Ddoc that is useful from its generated DDox page without requiring
the implementation source.

Where applicable, public documentation must state:

- what the symbol represents or does;
- parameter meaning and mutation;
- valid raster sample types;
- logical region and coordinate meaning;
- row/sample stride meaning, including signed strides;
- ownership and retention behavior;
- borrow/lifetime requirements;
- read-only versus writable access;
- `.init` semantics;
- empty-region behavior;
- overlap or aliasing semantics;
- destination injectivity requirements;
- checked failure semantics;
- no-write guarantees on failure;
- allocation behavior;
- `@safe`, `nothrow`, `@nogc`, and `pure` guarantees when part of the
  supported contract;
- numerical guarantees and limits;
- relevant performance contract, if any.

Do not copy the declaration into prose. Explain information the declaration
cannot express.

## 4. Public examples

Every public DDox symbol page in the supported release API must own a
compiler-checked documented `unittest` that DDox renders as an **Example**.

Examples must:

- normally use only `import raster;`;
- show realistic consumer code;
- be short enough to understand at a glance;
- demonstrate the declaration being documented;
- make ownership/lifetime or layout semantics visible when they matter;
- avoid internal execution details and research probes;
- compile as part of the documentation gate.

Regression tests are not documentation examples.

The generated DDox site is authoritative for whether an Example actually
renders on the intended symbol page.

## 5. Module documentation

Every supported public module included in generated API documentation must have
module Ddoc immediately before its `module` declaration.

The opening sentence tells a consumer what the module provides.

Required metadata:

~~~text
Authors:
Copyright:
License:
Date:
~~~

Useful optional sections include:

~~~text
Ownership:
Lifetime:
Layout:
Numerics:
Performance:
Safety:
See_Also:
~~~

Add a section only when it helps the reader.

## 6. Ownership and lifetime

Ownership and lifetime are first-class raster API contracts.

Documentation must make clear, where applicable:

- which type owns a physical resource;
- which type retains an owner;
- which type merely borrows;
- whether a view may outlive a lease or backing owner;
- whether a writable view proves mutable backing;
- whether returned slices/pointers/references escape;
- whether an operation allocates or retains anything.

Do not use vague phrases such as "safe view" when the real contract is a
specific retained-lifetime or scoped-borrow rule.

## 7. Regions, coordinates, and strides

Raster coordinate spaces must not be conflated.

Document whether values refer to:

- logical raster coordinates;
- descriptor coordinate (0, 0);
- resident backing offsets;
- dependency/request regions;
- execution-only row/sample strides.

When a public type accepts signed strides, explicitly document negative
traversal and the relation between stride units and sample size.

## 8. Failure and mutation

Checked APIs must document every supported failure category that matters to a
consumer.

For operations returning `bool` plus an error enum, describe:

- success behavior;
- each public failure category;
- whether destination storage is unchanged on failure;
- whether output parameters are initialized or overwritten;
- whether source/destination overlap is accepted, rejected, or handled by an
  exact fallback.

For D `out` parameters, remember that D initializes the value to `.init` on
entry.

## 9. Numerical documentation

State only guarantees supported by evidence.

Important raster distinctions include:

- exact integer/sample movement;
- exact `ubyte -> float` conversion;
- strict row-major floating-point reduction;
- pointwise floating-point transform behavior;
- neighbourhood ordering and boundary requirements;
- compiler/ISA-specific execution that must not change observable semantics.

Performance evidence belongs in BENCHMARK.md and ADRs. Public Ddoc should state
only performance properties that a consumer may rely on, such as allocation
behavior or absence of hidden threading.

## 10. Internal functions

Every non-trivial `private` or `package` function must have concise Ddoc
that lets a maintainer understand it without reconstructing the algorithm.

Document, where applicable:

- purpose;
- inputs and expected domain;
- result or mutation;
- preconditions;
- invariants preserved;
- ownership/lifetime assumptions;
- numerical assumptions;
- failure meaning.

Tiny helpers whose purpose is fully obvious may remain undocumented when review
can justify the exception.

## 11. Decision comments

Comments inside implementations explain **why**, not what the next statement
already says.

Decision comments are required for non-obvious choices involving:

- alias/overlap ordering;
- checked address arithmetic;
- signed-stride handling;
- trusted lifetime or pointer boundaries;
- compiler-specific optimizer workarounds;
- SIMD selection and thresholds;
- strict floating-point ordering;
- cache/residency accounting;
- deliberately deferred scheduling or parallelism;
- rejected simpler implementations where the reason matters to maintenance.

If removing a comment would make a future maintainer reasonably ask "why is
this written this way?", preserve the rationale locally or reference a nearby
ADR.

## 12. Documentation layers

Use each layer for one job:

- **Ddoc:** what the consumer can rely on;
- **Example:** how the consumer uses it;
- **internal Ddoc:** what an internal function does and assumes;
- **decision comment:** why a non-obvious implementation choice exists;
- **ADR:** persistent architecture/numerical/performance decision;
- **BENCHMARK.md / validation record:** evidence for qualified behavior.

Consumers should not need an ADR to discover ordinary API behavior.

## 13. Review method

### Automated

The documentation build must verify:

- Ddoc/DDox generation succeeds;
- public DDox symbol pages are inventoried;
- every required public page renders its own Example;
- every rendered Example comes from a documented compiler-checked `unittest`;
- public modules have module Ddoc;
- internal/private declarations do not leak into public DDox;
- non-trivial private/package functions satisfy the internal Ddoc contract;
- legacy inline `Example:` blocks are rejected.

### Human review

A reviewer verifies:

- public text is written for consumers;
- ownership, lifetime, layout and failure semantics are unambiguous;
- internal non-trivial functions explain inputs, outputs and invariants;
- important implementation choices explain why;
- examples are useful rather than ceremonial;
- generated DDox reads cleanly as documentation.

These judgments must not be reduced to word-count or comment-count heuristics.

## 14. Definition of done

A release is documentation-complete when:

- every supported public API is understandable from its DDox page;
- every required public API page has a rendered compiler-checked Example;
- every non-trivial internal function is documented well enough to maintain;
- important code decisions retain rationale;
- the generated public-only DDox site has been inspected as documentation;
- automated documentation gates pass;
- human documentation-quality review is signed off.
