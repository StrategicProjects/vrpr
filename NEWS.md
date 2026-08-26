# vrpr 0.1.1

Portability fixes for CRAN builders; no user-facing changes.

* Fixed compilation with LLVM 23's libc++ (CRAN's clang23 additional checks),
  which no longer provides `std::back_inserter` transitively: the vendored
  `search/LocalSearch.cpp` and `Solution.cpp` now include `<iterator>`
  explicitly.
* Fixed compilation on the CRAN macOS builders that use Apple's MacOSX11.3 SDK
  (r-release-macos-x86_64 and r-oldrel-macos), whose libc++ `<concepts>` lacks
  `std::convertible_to`: a small compatibility shim (`vrpr_compat.h`) supplies
  the concept where the standard library does not.
* `Route::Iterator` in the vendored sources now declares all five iterator
  member typedefs, as required by pre-C++20 `std::iterator_traits` on the same
  older libc++ (verified by compiling every translation unit against the
  MacOSX11.3 SDK's libc++ headers).
* These fixups are applied by `tools/vendor.R` on top of the verbatim PyVRP
  sources, so they survive re-vendoring.

# vrpr 0.1.0

First release.

* A tidy, pipe-friendly R interface to the 'PyVRP' vehicle routing solver. PyVRP's
  high-performance C++ core is vendored and rewired through 'cpp11', with no
  'Python' runtime dependency.
* Supports the capacitated VRP, time windows (VRPTW), heterogeneous fleets,
  multiple depots (MDVRP), prize-collecting (optional clients and mutually
  exclusive client groups), simultaneous pickup and delivery / backhaul, and
  multi-trip routes.
* `read_vrplib()` and `read_solomon()` read standard VRPLIB/TSPLIB and Solomon
  instances; `plot()` draws solutions with 'ggplot2'.
* The solver is a faithful port of PyVRP's iterated local search; objective and
  solution-quality parity with PyVRP is verified in `tools/benchmark/`.
