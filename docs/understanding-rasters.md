# Understanding raster data and raster-d

A raster is a rectangular grid of values. Each cell has a row and column.
The numbers might describe heights, temperatures, sensor measurements or
components of an image. A raster is **not necessarily a picture**.

For example, this tiny elevation-like grid has three columns and two rows:

```text
       x=0  x=1  x=2
y=0     10   12   16
y=1      9   13   20
```

The cell at `(x=1, y=0)` contains `12`. Its meaning (metres, degrees or
anything else) comes from the application, not from `raster-d`.

## Why not just use an array?

For a small grid, a D array is often enough. A raster library becomes useful
when an application must handle several aspects *consistently*:

- **Shape and coordinates:** rows, columns, planes and bounded subregions.
- **Storage layout:** the same logical grid can be stored with padding,
  interleaved planes or reversed rows (signed strides).
- **Memory lifetime:** a view can read existing storage without copying it,
  provided an owning lease keeps that storage alive.
- **Processing:** copying, converting, transforming, reducing and applying
  neighbourhood or convolution operations.
- **Large data:** managing resident blocks and materializing requested
  regions without assuming every logical cell fits in RAM.

These are *capabilities*, not requirements. For a handful of values, using an
ordinary array may remain simpler.

## A first real example

The following uses the current public API. The example allocates four bytes
and hands their ownership to a `RasterLease`. A read-only `RasterView`
then reads the lower-right sample of a 2 × 2 grid.

```d
import core.stdc.stdlib : malloc;
import raster;

void main() @system
{
    void* memory = malloc(4);
    assert(memory !is null);

    auto samples = (cast(ubyte*) memory)[0 .. 4];
    samples[] = [10, 20, 30, 40];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 4, resource));

    const PlaneByteLayout[1] layout = [
        PlaneByteLayout(0, 2, 1)
    ];

    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource, layout[], Region2D(0, 0, 2, 2), lease
    ).ok);

    scope auto view = lease.view();
    ubyte value;
    assert(view.trySample(0, 1, 1, value));
    assert(value == 40);
}
```

Here, `PlaneByteLayout(0, 2, 1)` describes an offset of zero bytes, two
bytes between adjacent rows and one byte between adjacent samples. It is
**not** a generic recipe for every sample type or layout; real imports must
provide a valid layout for their actual storage.

The import transfers the adopted resource into retained raster ownership
on success. Do not manually free the adopted memory after a successful import.
The lease controls resource lifetime; the view borrows access and must not
outlive the retained resource. The example deliberately uses `scope` for
the borrowed view.

## How a zero-copy region works

Imagine a grid:

```text
10  20  30  40
50  60  70  80
90 100 110 120
```

You want to process just:

```text
 60  70
100 110
```

A region of interest (ROI) describes *which coordinates* to use. A
`RasterView.tryRoi` child reuses the existing validated plane descriptors
and underlying storage; it does not duplicate those four sample values.
Both parent and child still depend on the retained backing lifetime.

The important distinction is:

- `RasterLease` retains physical resources and stable descriptor metadata.
- `RasterView` describes a borrowed, read-only region.
- `WritableRasterView` represents separately certified writable access;
  writable does **not** mean exclusive or thread-safe.

You normally start with a valid lease, obtain a view, and pass that view to
an operation. You do not need to construct raw descriptors or manage the
execution kernel yourself.

## What can I build?

| Task | How raster-d helps | What the application supplies |
| --- | --- | --- |
| Analyze an elevation grid | Value access, ROI, reductions and neighbourhood processing | Height units, terrain interpretation, data source |
| Inspect a temperature grid | Typed values, checked transformations and reductions | Sensor calibration and physical meaning |
| Process an image plane | Planes, regions, conversion and convolution | Colour model, codec, display semantics |
| Process a very large raster | Bounded residency, retained block reuse and caller-owned materialization | Source/provider, requests, scheduling and I/O |
| Work with unusual storage | Validated signed-stride and multi-plane layouts | Correct backing description and lifetime |

These are illustrative workflows. For instance, raster-d does **not** itself
read every GeoTIFF or satellite imagery service, interpret terrain features
or render a map. Higher-level imagery semantics belong in projects such as
`imagery-d`; an application may also use `raster-d` directly.

## Where raster-d stops

`raster-d` is a generic raster **core**, not a complete photo editor,
geospatial image stack or file-format decoder. It does not silently choose
worker threads, scheduling policy or network imagery sources.

Likewise, `@safe` and `scope` do not mean every possible lifetime misuse
is statically rejected under every supported compiler mode. Borrowed views
must remain within the retained backing lifetime. The current shared
lease owner uses non-atomic reference counting; concurrent manipulation of
shared owner handles is not an advertised contract.

For exact failure modes and signatures, use the generated public
Ddoc/DDox reference rather than treating this introduction as a substitute
for the API contracts.

## Continue learning

1. [Getting started](tutorial/getting-started.md) — create and read a tiny raster.
2. [Common operations](how-to/common-operations.md) — copy, conversion,
   transformations, reductions and convolution.
3. [Glossary](glossary.md) — common terms such as plane, stride and ROI.
4. [Accuracy and validation](accuracy-and-validation.md) — numerical promises.
5. [v0.2 API contract](API_0_2.md) — the frozen release-candidate surface.

This guide explains ideas; it does not introduce new APIs or change the
existing v0.2 ownership, numerical or performance contracts.
