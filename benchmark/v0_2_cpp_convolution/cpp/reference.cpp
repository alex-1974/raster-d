#include <algorithm>
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

namespace {
constexpr std::size_t warmups = 6;
constexpr std::size_t samples = 18;

#if defined(__GNUC__) || defined(__clang__)
__attribute__((noinline))
#endif
void execute_scalar(
    const float* source,
    std::size_t source_row_elements,
    std::size_t width,
    std::size_t height,
    float* destination)
{
    for (std::size_t y = 0; y < height; ++y)
    {
        const float* r0 = source + y * source_row_elements;
        const float* r1 = r0 + source_row_elements;
        const float* r2 = r1 + source_row_elements;
        float* dst = destination + y * width;

        for (std::size_t x = 0; x < width; ++x)
        {
            float total = 0.0f;
            total = total + r0[x + 0] *  0.125f;
            total = total + r0[x + 1] * -0.250f;
            total = total + r0[x + 2] *  0.375f;
            total = total + r1[x + 0] * -0.500f;
            total = total + r1[x + 1] *  1.250f;
            total = total + r1[x + 2] * -0.625f;
            total = total + r2[x + 0] *  0.750f;
            total = total + r2[x + 1] * -0.875f;
            total = total + r2[x + 2] *  0.500f;
            dst[x] = total;
        }
    }
}

std::uint64_t checksum(const float* data, std::size_t count)
{
    std::uint64_t hash = 1469598103934665603ULL;
    for (std::size_t i = 0; i < count; ++i)
    {
        std::uint32_t bits;
        std::memcpy(&bits, &data[i], sizeof(bits));
        hash ^= bits;
        hash *= 1099511628211ULL;
    }
    return hash;
}

long long time_scalar(
    const float* source,
    std::size_t source_row_elements,
    std::size_t width,
    std::size_t height,
    float* destination,
    std::size_t iterations)
{
    const auto start = std::chrono::steady_clock::now();
    for (std::size_t i = 0; i < iterations; ++i)
    {
#if defined(__GNUC__) || defined(__clang__)
        asm volatile("" ::: "memory");
#endif
        execute_scalar(source, source_row_elements, width, height, destination);
    }
    const auto end = std::chrono::steady_clock::now();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
}

long long median(std::array<long long, samples> values)
{
    std::sort(values.begin(), values.end());
    return (values[samples/2 - 1] + values[samples/2]) / 2;
}
}

int main(int argc, char** argv)
{
    const std::size_t width = argc >= 2 ? std::stoull(argv[1]) : 1024;
    const std::size_t height = argc >= 3 ? std::stoull(argv[2]) : 512;
    const std::size_t iterations = argc >= 4 ? std::stoull(argv[3]) : 8;
    const std::size_t row_elements = width + 2 + 32;

    std::vector<float> source(row_elements * (height + 2));
    std::vector<float> destination(width * height);

    for (std::size_t y = 0; y < height + 2; ++y)
        for (std::size_t x = 0; x < row_elements; ++x)
            source[y * row_elements + x] =
                static_cast<float>(static_cast<int>((y * 131 + x * 17) % 251) - 125) * 0.03125f;

    execute_scalar(source.data(), row_elements, width, height, destination.data());

    for (std::size_t i = 0; i < warmups; ++i)
        time_scalar(source.data(), row_elements, width, height, destination.data(), 1);

    std::array<long long, samples> times{};
    for (std::size_t sample = 0; sample < samples; ++sample)
        times[sample] = time_scalar(source.data(), row_elements, width, height, destination.data(), iterations);

    const auto median_ns = median(times);
    const double pixels = static_cast<double>(width * height * iterations);

    std::cout
        << "cpp_gate_cpp compiler=g++ path=cpp_scalar"
        << " ns_per_pixel=" << std::fixed << std::setprecision(6)
        << static_cast<double>(median_ns) / pixels
        << " checksum=" << std::hex << std::setw(16) << std::setfill('0')
        << checksum(destination.data(), destination.size())
        << std::dec << "\n";
}
