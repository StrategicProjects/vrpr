# Assemble the problem data (ProblemData) from a model

Builds PyVRP's C++ `ProblemData` structure from a
[`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md).
Locations follow PyVRP's convention: depots first (low indices), then
clients.

## Usage

``` r
vrp_problem_data(model, distance = NULL, duration = NULL)
```

## Arguments

- model:

  A
  [`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md)
  with at least one depot and one vehicle type.

- distance, duration:

  Matrices (`numeric`, `n x n`, locations in depots-then-clients order)
  of distance and duration. If `NULL`, they are computed as the rounded
  Euclidean distance between coordinates; `duration` defaults to
  `distance`.

## Value

A `vrpr_problem_data` object (a wrapper around a C++ external pointer).

## Details

Integer measures (distance, duration, cost, load) travel as R `numeric`
with integer semantics; non-integer values are rejected at the C++
boundary. Use `Inf` for "unconstrained" limits (e.g. `tw_late`).
