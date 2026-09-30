/++
    Package-internal compiler capability decisions.

    Compiler/version-specific optimized source forms are centralized here so
    algorithm modules do not scatter ad-hoc compiler tests.

    A capability is enabled only for compiler/frontend generations with
    retained benchmark and code-generation evidence.
+/
module raster.internal.compiler_capabilities;


/++
    Pure capability model used both by the active compiler gate and by unit
    tests for later frontend generations.
+/
private
enum bool ldc2111NegativeFloatNeighbourhoodRowBoundaryModel(
    bool isLdc,
    uint frontendVersion
) =
    isLdc
    && frontendVersion == 2111;


version (LDC)
{
    /++
        True only for the qualified LDC frontend generation.

        Evidence:

        - LDC 1.41.0 / D frontend 2.111.0 / LLVM 19.1.7 on the stable local
          reference machine;
        - LDC 1.41.0 / D frontend 2.111.0 / LLVM 20.1.5 on hosted diagnostic
          CI.

        Later frontend generations deliberately remain false until separately
        measured and inspected.
    +/
    package(raster)
    enum bool useLdc2111NegativeFloatNeighbourhoodRowBoundary =
        ldc2111NegativeFloatNeighbourhoodRowBoundaryModel!(
            true,
            __VERSION__
        );
}
else
{
    package(raster)
    enum bool useLdc2111NegativeFloatNeighbourhoodRowBoundary =
        false;
}


version (unittest)
{

static assert(
    ldc2111NegativeFloatNeighbourhoodRowBoundaryModel!(
        true,
        2111
    )
);

static assert(
    !ldc2111NegativeFloatNeighbourhoodRowBoundaryModel!(
        false,
        2111
    )
);

static assert(
    !ldc2111NegativeFloatNeighbourhoodRowBoundaryModel!(
        true,
        2112
    )
);

static assert(
    !ldc2111NegativeFloatNeighbourhoodRowBoundaryModel!(
        true,
        2113
    )
);

version (LDC)
{
    static if (__VERSION__ == 2111)
    {
        static assert(
            useLdc2111NegativeFloatNeighbourhoodRowBoundary
        );
    }
    else
    {
        static assert(
            !useLdc2111NegativeFloatNeighbourhoodRowBoundary
        );
    }
}
else
{
    static assert(
        !useLdc2111NegativeFloatNeighbourhoodRowBoundary
    );
}

} // version (unittest)
