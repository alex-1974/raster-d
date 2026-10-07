# M5.3 affine multiversioning diagnostic

This diagnostic follows `benchmark/v0_2_affine_codegen`.

Diagnostic 2 established that LDC 1.41.0 is sensitive to runtime-variable
sample strides in the 5x3 neighbourhood loop, while DMD 2.111.0 is not.

This harness evaluates a D-native internal multiversioning shape:

1. keep the general runtime signed-affine executor;
2. branch once per operation on small positive sample strides;
3. route common stride pairs to template-instantiated static executors;
4. retain the runtime executor as the fallback for all other values.

Measured stride pairs:

- 1 / 1 control;
- 2 / 2;
- 3 / 3;
- 4 / 4.

For 2/2, 3/3 and 4/4 the harness records:

- runtime: direct runtime-stride loop;
- dispatch: runtime branch into a template-static loop;
- static: direct template-static loop.

The experiment is diagnostic only. It does not change production code.

The XPS runner retains:

- DMD and LDC release builds;
- six CPU-pinned process measurements per compiler;
- complete objdump disassembly;
- recursive SHA256 manifest.
