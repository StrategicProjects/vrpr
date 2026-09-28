## Submission

vrpr 0.2.0 is a feature release. It upgrades the bundled solver core from
PyVRP 0.13.4 to PyVRP 0.14.0 and exposes the new upstream capabilities:

* Pickup-and-delivery problems (shipments) via `add_shipments()`.
* A new `unplanned()` accessor for optional clients/shipments left out of a
  solution (prize collecting).
* `routes()` gains `activity`, `shipment` and `trip` columns; existing columns
  and their meaning are unchanged for pure client instances.
* The search engine and penalty manager follow the upstream 0.14 design; the
  `init_load`/`init_tw`/`init_dist` arguments of `ils_params()` were removed
  because upstream no longer uses them (documented in NEWS).

The previous release (0.1.1, 2026-08-27) addressed the compilation problems
reported by Prof Brian Ripley; those portability fixes (explicit `<iterator>`
include for LLVM 23's libc++, and the `convertible_to` shim for the MacOSX11.3
SDK) are still applied to the new vendored sources by `tools/vendor.R`, and the
0.1.1 CRAN check results are clean on all flavours with no additional issues.

## Test environments

* local: macOS, R 4.6.0
* GitHub Actions: macOS / Windows / Ubuntu, R release, R-devel and R oldrel-1
* win-builder: R-devel and R-release
* macbuilder (CRAN's macOS toolchain, R-release and R-devel)
* every translation unit syntax-checked against the libc++ headers of Apple's
  MacOSX11.3 SDK (the toolchain of the r-release-macos-x86_64 and
  r-oldrel-macos CRAN builders, which macbuilder does not cover)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Bundled code

The package bundles the C++ source of the PyVRP solver (MIT-licensed) under
`src/vendor/pyvrp/` and rewires it with cpp11. The original copyright holders
(Niels Wouda and the PyVRP contributors, Thibaut Vidal, and ORTEC) are credited
with `cph`/`ctb` roles in `Authors@R` and detailed in `inst/COPYRIGHTS`. The
exact upstream version is pinned in `tools/PYVRP_VERSION` (PyVRP 0.14.0).

## Downstream dependencies

There are no downstream dependencies.
