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

constexpr std::size_t warmups = 4;
constexpr std::size_t samples = 16;

std::uint64_t double_bits(double value)
{
    std::uint64_t bits;
    static_assert(sizeof(bits) == sizeof(value));
    std::memcpy(&bits, &value, sizeof(bits));
    return bits;
}

#if defined(__GNUC__) || defined(__clang__)
__attribute__((noinline))
#endif
bool strict_sum(
    const float* base,
    std::ptrdiff_t row_stride,
    std::ptrdiff_t sample_stride,
    std::size_t width,
    std::size_t height,
    std::size_t plane_index,
    double& value)
{
    value = 0.0;

    if (plane_index != 0)
        return false;

    if (width == 0 || height == 0)
        return true;

    const float* row = base;

    for (std::size_t y = 0; y < height; ++y)
    {
        const float* sample = row;

        for (std::size_t x = 0; x < width; ++x)
        {
            value = value + static_cast<double>(*sample);

            if (x + 1 < width)
                sample += sample_stride;
        }

        if (y + 1 < height)
            row += row_stride;
    }

    return true;
}

long long time_sum(
    const float* base,
    std::ptrdiff_t row_stride,
    std::ptrdiff_t sample_stride,
    std::size_t width,
    std::size_t height,
    std::size_t iterations,
    std::uint64_t& checksum)
{
    checksum = 0;

    const auto start =
        std::chrono::steady_clock::now();

    for (std::size_t i = 0; i < iterations; ++i)
    {
#if defined(__GNUC__) || defined(__clang__)
        asm volatile("" ::: "memory");
#endif

        double value;

        if (!strict_sum(
                base,
                row_stride,
                sample_stride,
                width,
                height,
                0,
                value))
        {
            std::abort();
        }

        checksum ^=
            double_bits(value)
            + static_cast<std::uint64_t>(i);
    }

    const auto end =
        std::chrono::steady_clock::now();

    return std::chrono::duration_cast<
        std::chrono::nanoseconds
    >(end - start).count();
}

long long median(
    std::array<long long, samples> values)
{
    std::sort(values.begin(), values.end());

    return (
        values[samples / 2 - 1]
        + values[samples / 2]
    ) / 2;
}

} // namespace

int main(int argc, char** argv)
{
    const std::size_t width =
        argc >= 2
        ? std::stoull(argv[1])
        : 2048;

    const std::size_t height =
        argc >= 3
        ? std::stoull(argv[2])
        : 512;

    const std::size_t iterations =
        argc >= 4
        ? std::stoull(argv[3])
        : 32;

    const std::size_t row_elements =
        width + 32;

    std::vector<float> storage(
        row_elements * height
    );

    for (std::size_t y = 0; y < height; ++y)
    {
        for (std::size_t x = 0; x < row_elements; ++x)
        {
            storage[y * row_elements + x] =
                static_cast<float>(
                    static_cast<int>(
                        (y * 131 + x * 17) % 251
                    )
                    - 125
                )
                * 0.03125f;
        }
    }

    double qualification_value;

    if (!strict_sum(
            storage.data(),
            static_cast<std::ptrdiff_t>(row_elements),
            1,
            width,
            height,
            0,
            qualification_value))
    {
        return 2;
    }

    for (std::size_t warmup = 0; warmup < warmups; ++warmup)
    {
        std::uint64_t checksum;

        time_sum(
            storage.data(),
            static_cast<std::ptrdiff_t>(row_elements),
            1,
            width,
            height,
            1,
            checksum
        );
    }

    std::array<long long, samples> times{};
    std::uint64_t checksum = 0;

    for (std::size_t sample = 0; sample < samples; ++sample)
    {
        std::uint64_t one_checksum;

        times[sample] =
            time_sum(
                storage.data(),
                static_cast<std::ptrdiff_t>(row_elements),
                1,
                width,
                height,
                iterations,
                one_checksum
            );

        checksum ^= one_checksum;
    }

    const auto median_ns =
        median(times);

    const double logical_samples =
        static_cast<double>(
            width
            * height
            * iterations
        );

    std::cout
        << "sum_cpp_benchmark compiler=g++"
        << " api=strict_reference"
        << " width=" << width
        << " height=" << height
        << " iterations=" << iterations
        << " samples=" << samples
        << " median_ns=" << median_ns
        << " ns_per_sample="
        << std::fixed << std::setprecision(6)
        << static_cast<double>(median_ns)
            / logical_samples
        << " result_bits="
        << std::hex << std::setw(16) << std::setfill('0')
        << double_bits(qualification_value)
        << " checksum="
        << std::setw(16)
        << checksum
        << std::dec
        << "\n";

    return 0;
}
