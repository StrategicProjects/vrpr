## Submission

vrpr 0.2.3 is a minor feature release, prompted by a user request (GitHub
issue #4): `vrp_solve()` gains `distance` and `duration` arguments so that
travel matrices from a road network or routing engine can be passed directly;
the matrices are validated on the R side with actionable error messages; and a
new "Distances and durations" section documents the feature in the vignette
and README. The bundled C++ code is unchanged from 0.2.2.

The previous releases 0.2.1 (2026-09-30) and 0.2.2 (2026-10-06) followed 0.2.0
closely because both fixed installation failures reported by the CRAN team
(the MacOSX11.3 SDK builders and the additional `clang23` checks). 0.2.2 is OK
on all 13 CRAN flavours, with no additional issues.

## Test environments

* local: macOS 26.6 (arm64), R 4.6.0, `R CMD check --as-cran`
* win-builder: R-release
* GitHub Actions: macOS, Windows and Ubuntu (R release, devel and oldrel)
* every translation unit compiled (`-fsyntax-only`) against the libc++
  headers of LLVM 23 (as in the clang23 additional checks) and of Apple's
  MacOSX11.3 SDK (the r-release-macos-x86_64 and r-oldrel-macos builders),
  with no errors

## R CMD check results

0 errors | 0 warnings | 0 notes (local, `--as-cran --no-manual`)

## Bundled code

The package bundles the C++ source of the PyVRP solver (MIT-licensed) under
`src/vendor/pyvrp/` and rewires it with cpp11. The original copyright holders
(Niels Wouda and the PyVRP contributors, Thibaut Vidal, and ORTEC) are credited
with `cph`/`ctb` roles in `Authors@R` and detailed in `inst/COPYRIGHTS`. The
exact upstream version is pinned in `tools/PYVRP_VERSION` (PyVRP 0.14.0).

## Downstream dependencies

There are no downstream dependencies.
