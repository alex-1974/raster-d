/++
    Common fallible-operation result vocabulary.

    Raster libraries keep their own error enums and use these aliases only for
    the transport of success and failure across a public API boundary.
+/
module raster.result;

public import error_d : Result;

/// Result carrying a value or a library-specific error.
alias RasterResult(T, E) = Result!(T, E);

/// Result for an operation whose successful outcome has no value.
alias RasterVoidResult(E) = Result!(void, E);

@safe unittest
{
    enum ExampleError { invalid }
    alias ExampleResult = RasterResult!(int, ExampleError);

    auto success = ExampleResult.success(7);
    assert(success.hasValue);
    assert(success.value() == 7);

    auto failure = ExampleResult.failure(ExampleError.invalid);
    assert(failure.hasError);
    assert(failure.error() == ExampleError.invalid);
}
