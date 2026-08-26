#ifndef VRPR_COMPAT_H
#define VRPR_COMPAT_H

// vrpr addition (not part of upstream PyVRP; written by tools/vendor.R).
//
// Compatibility shim for C++20 <concepts> on older standard libraries still
// used by some CRAN builders. Apple's MacOSX11.3 SDK (used by the
// r-release-macos-x86_64 and r-oldrel-macos builders) ships a libc++ whose
// <concepts> implements only std::same_as: std::convertible_to appears in the
// synopsis comment but is never defined, and the SDK does not define the
// feature-test macro __cpp_lib_concepts. We key on that macro: where the
// concepts library is complete we simply reuse std::convertible_to, otherwise
// we define the C++20 [concept.convertible] wording ourselves in a separate
// namespace (never in namespace std).
//
// tools/vendor.R patches the vendored PyVRP sources to use
// pyvrp::compat::convertible_to instead of std::convertible_to.

#if defined(__has_include)
#if __has_include(<version>)
#include <version>
#endif
#endif

#if defined(__cpp_lib_concepts)
#include <concepts>
#else
#include <type_traits>
#include <utility>
#endif

namespace pyvrp::compat
{
#if defined(__cpp_lib_concepts)
using std::convertible_to;
#else
// C++20 [concept.convertible], as specified in the standard.
template <typename From, typename To>
concept convertible_to = std::is_convertible_v<From, To>
                         && requires { static_cast<To>(std::declval<From>()); };
#endif
}  // namespace pyvrp::compat

#endif  // VRPR_COMPAT_H
