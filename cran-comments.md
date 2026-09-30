## Submission

vrpr 0.2.1 is a patch release that fixes the ERROR in the CRAN checks of 0.2.0
on r-release-macos-x86_64, r-oldrel-macos-arm64 and r-oldrel-macos-x86_64:

```
vendor/pyvrp/search/SearchSpace.cpp:52:66: error: reference to local binding
'activity' declared in enclosing function
```

A lambda in the bundled PyVRP sources captured a structured binding, which is
valid only from C++20 and is rejected by the Apple clang of the MacOSX11.3 SDK.
The binding is now copied into a plain reference before the lambda (applied by
`tools/vendor.R`, so it survives re-vendoring). I scanned the rest of the
bundled sources for the same pattern and found no other occurrence.

The only other change is author metadata: the maintainer's name is now spelled
with its accent ("André Leite"; same person and e-mail address), a
co-author's surname and e-mail were corrected (Marcos Wasiliew), ORCID iDs were
added and Júlia Nascimento Barreto joins as author. The code is otherwise
identical to 0.2.0.

## Test environments

* local: macOS 26.6 (arm64), R 4.6.0, `R CMD check --as-cran`
* macbuilder: r-release (macOS 26.6 host, SDK 14.4, arm64) -- Status: OK
* every translation unit compiled with clang's `-Wpre-c++20-compat`
  diagnostic, which flags lambda captures of structured bindings: the 0.2.0
  `SearchSpace.cpp` triggers it at the same line and column as the CRAN error
  (52:66), and no translation unit of 0.2.1 does. None of the builders
  available to me uses the MacOSX11.3 SDK toolchain of the failing flavours, so
  this is the closest reproduction I can offer.

## R CMD check results

0 errors | 0 warnings | 2 notes

* `Days since last update: 2` -- this release only fixes the ERROR above.
* `checking HTML version of manual ... NOTE`: skipped because the local HTML
  Tidy is too old (local tooling, not a package issue).

## Bundled code

The package bundles the C++ source of the PyVRP solver (MIT-licensed) under
`src/vendor/pyvrp/` and rewires it with cpp11. The original copyright holders
(Niels Wouda and the PyVRP contributors, Thibaut Vidal, and ORTEC) are credited
with `cph`/`ctb` roles in `Authors@R` and detailed in `inst/COPYRIGHTS`. The
exact upstream version is pinned in `tools/PYVRP_VERSION` (PyVRP 0.14.0).

## Downstream dependencies

There are no downstream dependencies.
