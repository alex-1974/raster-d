import ldc.attributes : llvmFastMathFlag;

@llvmFastMathFlag("reassoc")
double probe(double a, double b)
{
    return a + b;
}
