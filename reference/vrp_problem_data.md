# Assemble the problem data (ProblemData) from a model

Builds PyVRP's C++ `ProblemData` structure from a
[`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md).
Locations follow vrpr's convention: depots first (low indices), then
clients, then one pickup and one delivery location per shipment.

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

  Optional `n x n` numeric matrices of travel distance and travel
  duration between all `n` locations, e.g. from a road network or a
  routing engine (OSRM, osmnx, ...). Rows and columns follow vrpr's
  location order: depots (in the order they were added), then clients,
  then one pickup and one delivery location per shipment. Asymmetric
  matrices are fine. Entries must be non-negative integers (PyVRP uses
  integer measures), so round to the unit you want (metres, seconds)
  first. If `distance` is `NULL`, it is computed as the rounded
  Euclidean distance between the coordinates (the TSPLIB `EUC_2D`
  convention). If `duration` is `NULL`, it is taken equal to `distance`;
  a warning is issued when that happens with an explicit `distance` and
  the model has temporal features (time windows, service times, maximum
  duration, ...), because those are then measured in distance units.
  With explicit matrices the coordinates in
  [`add_depot()`](https://strategicprojects.github.io/vrpr/reference/add_depot.md)/[`add_clients()`](https://strategicprojects.github.io/vrpr/reference/add_clients.md)
  are only used by
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Value

A `vrpr_problem_data` object (a wrapper around a C++ external pointer).

## Details

Integer measures (distance, duration, cost, load) travel as R `numeric`
with integer semantics; non-integer values are rejected at the C++
boundary. Use `Inf` for "unconstrained" limits (e.g. `tw_late`).

## Examples

``` r
# A triangle depot/A/B with an asymmetric road-network matrix (metres) and
# a separate travel-time matrix (seconds).
clients <- tibble::tibble(x = c(1, 2), y = c(0, 1), demand = c(5, 5))
dist <- matrix(c(0, 1200, 1500,
                 1300, 0, 800,
                 1500, 900, 0), 3, byrow = TRUE)
time <- matrix(c(0, 180, 240,
                 200, 0, 120,
                 240, 130, 0), 3, byrow = TRUE)
m <- vrp_model() |>
  add_depot(0, 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 1, capacity = 10)
pd <- vrp_problem_data(m, distance = dist, duration = time)
pd
#> 
#> ── ProblemData ─────────────────────────────────────────────────────────────────
#> • 2 clients - 1 depot (3 locations)
#> • 1 vehicle type - 1 vehicle
#> • 1 load dimension - 1 profile
#> • time windows: no
```
