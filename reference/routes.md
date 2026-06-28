# Routes of a solution, in long (tidy) format

Routes of a solution, in long (tidy) format

## Usage

``` r
routes(x, ...)
```

## Arguments

- x:

  A
  [`vrp_solution()`](https://strategicprojects.github.io/vrpr/reference/vrp_solution.md).

- ...:

  Unused.

## Value

A tibble with one row per visit: `route_id`, `depot` (start depot,
1-based), `position`, `client`, `vehicle_type`, `start_service` (start
of service) and `wait` (waiting time). The last two are only meaningful
with time windows (VRPTW); `depot` varies in the MDVRP.
