# v0.2 binary multiply codegen diagnostic

This retained M5.3 diagnostic isolates the small float multiply wrapper/executor
signal from the qualified binary-transform family.

It compares exactly the same padded Canonical float workload through:

- `public_zip`: public `zipTransformInto!multiplyFloat`;
- `public_wrapper`: public `multiplyInto`;
- `hot_executor`: approved internal Canonical zip executor.

The first comparison distinguishes arithmetic-wrapper source form from the
generic public zip path. The executor comparison retains the already-approved
validation-free Canonical execution shape.

All paths use the same input values, geometry and destination layout. Exact
output checksums and padding canaries are verified before timing. The runner
uses six CPU-pinned processes per compiler, records compiler/platform/frequency
metadata, retains complete `objdump -d -C` disassembly and writes a recursive
SHA256 manifest.

No production semantics, public API or execution policy are changed by this
diagnostic.
