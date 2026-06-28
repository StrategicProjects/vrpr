# Build a solution from explicit routes

Build a solution from explicit routes

## Usage

``` r
vrp_solution(problem_data, routes)
```

## Arguments

- problem_data:

  A
  [`vrp_problem_data()`](https://strategicprojects.github.io/vrpr/reference/vrp_problem_data.md).

- routes:

  A list of integer vectors; each vector is a route given as *client
  numbers* (1..n_clients), in visit order. All routes use the first
  vehicle type.

## Value

A `vrpr_solution` object.
