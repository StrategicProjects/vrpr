## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Notes

* The package vendors the C++ core of the PyVRP solver (MIT-licensed) under
  `src/vendor/pyvrp/` and rewires it with cpp11. The copyright holders of the
  vendored code are credited with `cph`/`ctb` roles in `Authors@R` and detailed
  in `inst/COPYRIGHTS`.
* The C++ core requires C++20 (`SystemRequirements: C++20, GNU make`).
