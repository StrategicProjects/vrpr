// Sanity binding: proves the C++20 + cpp11 toolchain works, alongside the
// vendored PyVRP C++ core (src/vendor/pyvrp/).
//
// Uses a C++20 feature header only to make sure CXX_STD = CXX20 is in effect.

#include <cpp11.hpp>

#include <string>

// Returns the C++ standard actually used at compile time.
[[cpp11::register]]
int vrpr_cpp_standard() {
  return static_cast<int>(__cplusplus / 100L % 100L);  // e.g. 20 for C++20
}

// Confirms the presence of a C++20 feature.
[[cpp11::register]]
bool vrpr_has_cxx20() {
#if defined(__cpp_lib_span) || __cplusplus >= 202002L
  return true;
#else
  return false;
#endif
}

// Trivial greeting, handy as a smoke test of the cpp11 binding.
[[cpp11::register]]
std::string vrpr_hello() {
  return std::string("vrpr: C++ core ready, backed by PyVRP");
}
