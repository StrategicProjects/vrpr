# Solve a VRP model

Runs the iterated local search (ILS) solver on a model, using PyVRP's
vendored C++ core.

## Usage

``` r
vrp_solve(model, stop, seed = 42L, params = ils_params(), display = TRUE)
```

## Arguments

- model:

  A
  [`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md)
  or an already-assembled
  [`vrp_problem_data()`](https://strategicprojects.github.io/vrpr/reference/vrp_problem_data.md).

- stop:

  A stopping criterion (see
  [vrpr_stop](https://strategicprojects.github.io/vrpr/reference/vrpr_stop.md)),
  e.g. `max_runtime(10)`.

- seed:

  Integer seed for reproducibility.

- params:

  Solver parameters (see
  [`ils_params()`](https://strategicprojects.github.io/vrpr/reference/ils_params.md)).

- display:

  Show progress via `{cli}`?

## Value

A `vrpr_result` object with the best solution, cost, routes and run
statistics. Use
[`cost()`](https://strategicprojects.github.io/vrpr/reference/cost.md),
[`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
and [`summary()`](https://rdrr.io/r/base/summary.html) to inspect it.

## Examples

``` r
clients <- tibble::tibble(
  x = c(10, 25, 40, 15), y = c(5, 30, 12, 22),
  demand = c(10, 15, 8, 12)
)
res <- vrp_model() |>
  add_depot(x = 0, y = 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 3, capacity = 50) |>
  vrp_solve(stop = max_iterations(200), display = FALSE)

cost(res)
#> [1] 105
routes(res)
#> # A tibble: 4 × 7
#>   route_id depot position client vehicle_type start_service  wait
#>      <int> <int>    <int>  <int>        <int>         <dbl> <dbl>
#> 1        1     1        1      1            1            11     0
#> 2        1     1        2      3            1            42     0
#> 3        1     1        3      2            1            65     0
#> 4        1     1        4      4            1            78     0
```
