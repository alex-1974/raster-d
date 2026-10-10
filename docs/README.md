# raster-d documentation

Start here if you use the library rather than maintain it.

**New to raster data?** Read [What is a raster and why use raster-d?](understanding-rasters.md) before the API tutorial.

- [Getting started](tutorial/getting-started.md) shows how to create a retained raster and read samples.
- [Common operations](how-to/common-operations.md) shows copy, conversion, transform, reduction, and convolution workflows.
- [Glossary](glossary.md) defines the raster terms used by the API.
- [Accuracy and validation](accuracy-and-validation.md) explains the numerical contracts and how they are qualified.
- [v0.2 frozen API contract](API_0_2.md) records the audited release-candidate API at `freeze/api-0.2.0`.
- [v0.1 API baseline](API.md) records the released 0.1 contract.

Generated Ddoc/DDox remains the authoritative declaration-level API reference.

Release maintainers: the [final release-content gate](V0_2_FINAL_RELEASE_CONTENT_GATE.md) is mandatory immediately before v0.2 promotion and publication.

Maintainer material lives separately:

- `adr/` records durable architecture decisions;
- `architecture/` explains internal architecture;
- `BENCHMARK.md` at the repository root summarizes retained production performance evidence;
- experimental work and raw evidence belong in `raster-d-research`.

User documentation explains how to solve a problem. Engineering evidence explains why the implementation is trusted.
