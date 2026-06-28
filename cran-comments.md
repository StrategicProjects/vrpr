## Submission

This is a new submission (vrpr 0.1.0).

## Test environments

* local: macOS, R 4.6.0
* GitHub Actions: macOS / Windows / Ubuntu, R release, R-devel and R oldrel-1
* win-builder: R-devel and R-release

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Andre Leite <leite@castlab.org>'
  New submission
```

This is the expected note for a first submission.

## Bundled code

The package bundles the C++ source of the PyVRP solver (MIT-licensed) under
`src/vendor/pyvrp/` and rewires it with cpp11. The original copyright holders
(Niels Wouda and the PyVRP contributors, Thibaut Vidal, and ORTEC) are credited
with `cph`/`ctb` roles in `Authors@R` and detailed in `inst/COPYRIGHTS`. The
exact upstream version is pinned in `tools/PYVRP_VERSION` (PyVRP 0.13.4).

## System requirements

The C++ core requires C++20 (`SystemRequirements: C++20, GNU make`). It builds on
the GitHub Actions matrix above (R-devel, release and oldrel-1 on Windows, macOS
and Linux).

## Downstream dependencies

There are no downstream dependencies (new package).
