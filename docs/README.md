# raster-d documentation

Start here if you use the library rather than maintain it.

**New to raster data?** Read [What is a raster and why use raster-d?](understanding-rasters.md) before the API tutorial.

- [Getting started](tutorial/getting-started.md) shows how to create a retained raster and read samples.
- [Common operations](how-to/common-operations.md) shows copy, conversion, transform, reduction, and convolution workflows.
- [Glossary](glossary.md) defines the raster terms used by the API.
- [Accuracy and validation](accuracy-and-validation.md) explains the numerical contracts and how they are qualified.
- [v0.2 published release notes and historical qualification](V0_2_RELEASE_NOTES.md) describe changes, qualification evidence and remaining retrospective audits.
- [v0.2 frozen API contract](API_0_2.md) records the frozen published API at `freeze/api-0.2.0`.
- [v0.1 API baseline](API.md) records the released 0.1 contract.

Generated Ddoc/DDox remains the authoritative declaration-level API reference.

Release maintainers: see the [Ddoc/DDox qualification status](V0_2_DDOX_QUALIFICATION.md)
and the [final release-content gate](V0_2_FINAL_RELEASE_CONTENT_GATE.md).
The historical prepromotion editorial/content sign-off was not fully
completed; it must not be retroactively marked PASS.

Maintainer material lives separately:

- `adr/` records durable architecture decisions;
- `architecture/` explains internal architecture;
- `BENCHMARK.md` at the repository root summarizes retained production performance evidence;
- experimental work and raw evidence belong in `raster-d-research`.

User documentation explains how to solve a problem. Engineering evidence explains why the implementation is trusted.
