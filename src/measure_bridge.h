#ifndef VRPR_MEASURE_BRIDGE_H
#define VRPR_MEASURE_BRIDGE_H

// Numeric boundary R <-> PyVRP.
//
// PyVRP measures (Cost/Distance/Duration/Load) are int64_t; Coordinate is
// double. R has no native 64-bit integer, so measures travel as `double`
// (numeric) with integer semantics, validated here:
//
//   * finite + integer + |x| <= 2^53  -> exact int64_t
//   * Inf/NA ("unconstrained" sentinel) -> numeric_limits<int64_t>::max()
//
// 2^53 (~9.0e15) is the largest integer exactly representable as a double; it is
// non-binding for realistic VRP magnitudes.

#include <cpp11.hpp>

#include <cmath>
#include <cstdint>
#include <limits>

namespace vrpr
{
// Largest integer exactly representable as a double (2^53).
inline constexpr double kMaxExactInt = 9007199254740992.0;

// Converts an R double to int64, requiring integer semantics.
inline std::int64_t as_i64(double x, char const *what)
{
    if (!std::isfinite(x))
        cpp11::stop(
            "%s must be finite; use the 'unconstrained' value (Inf) only where allowed.",
            what);

    if (x != std::floor(x))
        cpp11::stop("%s must be an integer (PyVRP uses integer measures); "
                    "got %g. Rescale the data if necessary.",
                    what, x);

    if (std::abs(x) > kMaxExactInt)
        cpp11::stop("%s exceeds 2^53 and is not exactly representable as a double.",
                    what);

    return static_cast<std::int64_t>(x);
}

// Like as_i64, but maps non-finite (Inf/NA) to the int64 max sentinel, which
// PyVRP interprets as "unconstrained".
inline std::int64_t as_i64_or_max(double x, char const *what)
{
    if (!std::isfinite(x))
        return std::numeric_limits<std::int64_t>::max();
    return as_i64(x, what);
}
}  // namespace vrpr

#endif  // VRPR_MEASURE_BRIDGE_H
