# M5.3 neighbourhood public/hot codegen diagnostic

This is a diagnostic benchmark for Issue #117. It does not define public API or
production semantics.

The retained M5.1 evidence showed that centered 3x3 generic and legacy public
operations are equivalent, while both are far slower than the approved hot
executor on the reference XPS.

The diagnostic separates four shapes:

~~~text
public
    production tryApplyRasterNeighbourhood3x3

hot_direct
    approved executeApprovedNeighbourhood3x3 called directly

hot_noinline
    same approved executor behind one benchmark-local noinline wrapper

preflight_noinline_hot
    benchmark-local replica of the fixed Canonical structural preflight,
    followed by the same benchmark-local noinline hot-executor wrapper

preflight_only
    the same diagnostic structural preflight without pixel execution
~~~

The preflight replica is deliberately limited to the fixed benchmark workload:
valid independent Canonical float source/destination with complete 3x3 halo.
It uses the production stride queries, ROI construction, injectivity check and
validated affine overlap classifier. It is diagnostic evidence only and is not
a second production operation.

Interpretation:

- if hot_direct and hot_noinline are at parity, one call boundary is cheap;
- if preflight_only is tiny relative to one full operation, validation work
  cannot explain the M5.1 per-pixel cliff by itself;
- if preflight_noinline_hot approaches hot execution while production public
  remains much slower, code-generation/inlining context is implicated;
- no production change is promoted from this harness without reference-XPS
  timing and generated-code inspection.

Run:

~~~bash
bash benchmark/v0_2_neighbourhood_codegen/run_xps.sh
~~~
