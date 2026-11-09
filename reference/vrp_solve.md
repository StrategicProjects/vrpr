# Solve a VRP model

Runs the iterated local search (ILS) solver on a model, using PyVRP's
vendored C++ core.

## Usage

``` r
vrp_solve(
  model,
  stop,
  seed = 42L,
  params = ils_params(),
  display = TRUE,
  distance = NULL,
  duration = NULL
)
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

- distance, duration:

  Optional `n x n` integer-valued matrices of travel distance and travel
  duration between all locations (depots, then clients, then shipment
  pickup/delivery pairs), e.g. from a road network. By default the
  rounded Euclidean distance between coordinates is used for both. See
  [`vrp_problem_data()`](https://strategicprojects.github.io/vrpr/reference/vrp_problem_data.md)
  for the details. Only used when `model` is a
  [`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md).

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
#> # A tibble: 4 × 10
#>   route_id depot position activity client shipment  trip vehicle_type
#>      <int> <int>    <int> <chr>     <int>    <int> <int>        <int>
#> 1        1     1        1 client        4       NA     1            1
#> 2        1     1        2 client        2       NA     1            1
#> 3        1     1        3 client        3       NA     1            1
#> 4        1     1        4 client        1       NA     1            1
#> # ℹ 2 more variables: start_service <dbl>, wait <dbl>

# With travel distances (m) and times (s) from a road network instead of
# Euclidean distances: pass the matrices directly. Here a toy asymmetric
# matrix stands in for the output of a routing engine.
n <- nrow(clients) + 1
set.seed(1)
dist <- matrix(sample(500:3000, n * n, replace = TRUE), n)
diag(dist) <- 0
res_road <- vrp_model() |>
  add_depot(x = 0, y = 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 3, capacity = 50) |>
  vrp_solve(stop = max_iterations(200), display = FALSE,
            distance = dist, duration = round(dist / 10))
cost(res_road)
#> [1] 5832
```
