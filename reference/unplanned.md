# Unplanned activities of a solution

Optional clients and shipments that are not part of any route
(prize-collecting problems).

## Usage

``` r
unplanned(x, ...)
```

## Arguments

- x:

  A
  [`vrp_solution()`](https://strategicprojects.github.io/vrpr/reference/vrp_solution.md)
  or
  [`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md)
  result.

- ...:

  Unused.

## Value

A tibble with columns `activity` (`"client"` or `"pickup"`/
`"delivery"`) and `index` (1-based client or shipment number).
