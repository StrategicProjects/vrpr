## Submission

vrpr 0.2.2 is a patch release requested by the CRAN team (e-mail of
2026-10-06, deadline 2026-10-27). It fixes the installation failure in the
additional `clang23` checks (LLVM 23.1 libc++, Fedora):

```
vendor/pyvrp/Client.cpp:57:14: error: no member named 'any_of' in namespace 'std'
vendor/pyvrp/VehicleType.cpp:81:14: error: no member named 'any_of' in namespace 'std'
```

libc++ 23 dropped many transitive includes; two of the bundled PyVRP sources
used `std::any_of` without including `<algorithm>`. The include is now added
by `tools/vendor.R` (so it survives re-vendoring), next to the `<iterator>`
fixups made for the same reason in 0.1.1. The code is otherwise identical to
0.2.1, which is OK on all 13 regular CRAN flavours.

## Test environments

* local: macOS 26.6 (arm64), R 4.6.0, `R CMD check --as-cran`
* every translation unit compiled (`-fsyntax-only`) against the libc++
  headers of LLVM 23.1.2 (Homebrew), which reproduces the eight clang23
  errors on 0.2.1 character for character and none on 0.2.2
* every translation unit also compiled against the libc++ headers of Apple's
  MacOSX11.3 SDK (the toolchain of the r-release-macos-x86_64 and
  r-oldrel-macos builders), with no errors

## R CMD check results

0 errors | 0 warnings | 0 notes (local, `--as-cran --no-manual`)

The CRAN incoming checks will report `Days since last update: 5`: this release
only fixes the clang23 ERROR above, at the CRAN team's request.

## Bundled code

The package bundles the C++ source of the PyVRP solver (MIT-licensed) under
`src/vendor/pyvrp/` and rewires it with cpp11. The original copyright holders
(Niels Wouda and the PyVRP contributors, Thibaut Vidal, and ORTEC) are credited
with `cph`/`ctb` roles in `Authors@R` and detailed in `inst/COPYRIGHTS`. The
exact upstream version is pinned in `tools/PYVRP_VERSION` (PyVRP 0.14.0).

## Downstream dependencies

There are no downstream dependencies.
