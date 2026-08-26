## Submission

vrpr 0.1.1 is a patch release fixing the compilation problems reported by
Prof Brian Ripley on 2026-08-26 (deadline 2026-09-16):

* The clang23 additional issue (LLVM 23's libc++ dropped transitive includes):
  `std::back_inserter` is now included explicitly via `<iterator>` in the
  bundled `search/LocalSearch.cpp` (and `Solution.cpp`).
* The installation ERRORs on r-release-macos-x86_64 and the r-oldrel-macos
  builders: their MacOSX11.3 SDK ships a libc++ whose `<concepts>` implements
  only `std::same_as`. A small compatibility header now supplies
  `convertible_to` (in its own namespace, keyed on `__cpp_lib_concepts`) where
  the standard library does not provide it. A custom iterator also gained the
  two member typedefs required by that SDK's pre-C++20 `std::iterator_traits`.

All translation units were verified to compile against the MacOSX11.3 SDK's
libc++ headers (reproducing the reported errors first, then confirming the
fix). There are no user-facing changes.

## Test environments

* local: macOS, R 4.6.0
* GitHub Actions: macOS / Windows / Ubuntu, R release, R-devel and R oldrel-1
* win-builder: R-devel and R-release
* macbuilder (CRAN's macOS release toolchain)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Bundled code

The package bundles the C++ source of the PyVRP solver (MIT-licensed) under
`src/vendor/pyvrp/` and rewires it with cpp11. The original copyright holders
(Niels Wouda and the PyVRP contributors, Thibaut Vidal, and ORTEC) are credited
with `cph`/`ctb` roles in `Authors@R` and detailed in `inst/COPYRIGHTS`. The
exact upstream version is pinned in `tools/PYVRP_VERSION` (PyVRP 0.13.4).

## Downstream dependencies

There are no downstream dependencies.
