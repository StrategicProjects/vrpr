# Getting started with vrpr

`vrpr` is a tidyverse-style interface to the
[PyVRP](https://github.com/PyVRP/PyVRP) vehicle-routing solver. You
build a model by piping together depots, clients and vehicle types, then
call
[`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md).
The heavy lifting runs in PyVRP’s C++ core (rewired with cpp11), so
there is **no Python dependency**.

``` r

library(vrpr)
```

## A first CVRP

The capacitated VRP (CVRP) is the base case: clients have a `demand`,
vehicles a `capacity`, and we minimise total distance. The data boundary
is a tibble.

``` r

set.seed(1)
clients <- tibble::tibble(
  x = round(runif(20, -50, 50)),
  y = round(runif(20, -50, 50)),
  demand = sample(5:15, 20, replace = TRUE)
)

model <- vrp_model() |>
  add_depot(x = 0, y = 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 5, capacity = 50)

res <- vrp_solve(model, stop = max_iterations(500), seed = 1, display = FALSE)
res
#> 
#> ── vrpr result ─────────────────────────────────────────────────────────────────
#> • cost 567 - feasible
#> • 5 routes - 20 clients
#> • 500 iterations - 0.09s
```

Inspect the result with
[`cost()`](https://strategicprojects.github.io/vrpr/reference/cost.md),
[`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
(a tidy long table) and
[`summary()`](https://rdrr.io/r/base/summary.html):

``` r

cost(res)
#> [1] 567
head(routes(res))
#> # A tibble: 6 × 10
#>   route_id depot position activity client shipment  trip vehicle_type
#>      <int> <int>    <int> <chr>     <int>    <int> <int>        <int>
#> 1        1     1        1 client       16       NA     1            1
#> 2        1     1        2 client        9       NA     1            1
#> 3        1     1        3 client       15       NA     1            1
#> 4        1     1        4 client       17       NA     1            1
#> 5        2     1        1 client        8       NA     1            1
#> 6        2     1        2 client       20       NA     1            1
#> # ℹ 2 more variables: start_service <dbl>, wait <dbl>
summary(res)
#> # A tibble: 1 × 9
#>    cost is_feasible num_routes num_trips num_clients num_shipments distance
#>   <dbl> <lgl>            <int>     <int>       <int>         <int>    <dbl>
#> 1   567 TRUE                 5         5          20             0      567
#> # ℹ 2 more variables: iterations <int>, runtime <dbl>
```

If [ggplot2](https://ggplot2.tidyverse.org) is installed,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
routes:

``` r

plot(res)
```

![](vrpr_files/figure-html/plot-cvrp-1.png)

## Stopping criteria

[`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md)
runs until a stopping criterion fires. Combine time- and iteration-based
limits as needed:

``` r

vrp_solve(model, stop = max_runtime(seconds = 10)) # wall-clock budget
vrp_solve(model, stop = max_iterations(5000))      # iteration budget
vrp_solve(model, stop = no_improvement(1000))      # stop when stuck
```

## Time windows (VRPTW)

Add `tw_early`, `tw_late` and `service` columns to the clients to turn
the model into a VRP with time windows. The solver respects the windows,
and
[`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
reports the `start_service` and `wait` time of each visit.

``` r

tw_clients <- tibble::tibble(
  x        = c(10, 20, 30, 40, 50, 60),
  y        = 0,
  demand   = 10,
  tw_early = c(0, 30, 60, 90, 120, 150),
  tw_late  = c(50, 80, 110, 140, 170, 200),
  service  = 10
)

vrptw <- vrp_model() |>
  add_depot(0, 0, tw_early = 0, tw_late = 500) |>
  add_clients(tw_clients) |>
  add_vehicle_type(num_available = 2, capacity = 60, tw_early = 0, tw_late = 500)

res_tw <- vrp_solve(vrptw, stop = max_iterations(500), seed = 1, display = FALSE)
routes(res_tw)[, c("route_id", "client", "start_service", "wait")]
#> # A tibble: 6 × 4
#>   route_id client start_service  wait
#>      <int>  <int>         <dbl> <dbl>
#> 1        1      1            50     0
#> 2        1      2            70     0
#> 3        1      3            90     0
#> 4        1      4           110     0
#> 5        1      6           150    10
#> 6        1      5           170     0
```

## Heterogeneous fleet

Call
[`add_vehicle_type()`](https://strategicprojects.github.io/vrpr/reference/add_vehicle_type.md)
several times for a fleet of different vehicles. Here a cheap type and
an expensive one share the same capacity; the solver prefers the cheaper
type and only uses what it needs.

``` r

het <- vrp_model() |>
  add_depot(0, 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 3, capacity = 50, unit_distance_cost = 1) |>
  add_vehicle_type(num_available = 3, capacity = 50, unit_distance_cost = 5)

res_het <- vrp_solve(het, stop = max_iterations(500), seed = 1, display = FALSE)
table(routes(res_het)$vehicle_type)
#> 
#>  1  2 
#> 12  8
```

## Multiple depots (MDVRP)

Add several depots and base each vehicle type at one of them with
`add_vehicle_type(depot = i)`. The
[`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
output gains a `depot` column.

``` r

mdvrp <- vrp_model() |>
  add_depot(x = -50, y = 0) |>
  add_depot(x =  50, y = 0) |>
  add_clients(tibble::tibble(
    x = c(-55, -45, -50, 55, 45, 50),
    y = c(5, -5, 10, 5, -5, 8),
    demand = 10
  )) |>
  add_vehicle_type(num_available = 3, capacity = 50, depot = 1) |>
  add_vehicle_type(num_available = 3, capacity = 50, depot = 2)

res_md <- vrp_solve(mdvrp, stop = max_iterations(500), seed = 1, display = FALSE)
routes(res_md)[, c("route_id", "depot", "client")]
#> # A tibble: 6 × 3
#>   route_id depot client
#>      <int> <int>  <int>
#> 1        1     1      2
#> 2        1     1      3
#> 3        1     1      1
#> 4        2     2      5
#> 5        2     2      6
#> 6        2     2      4
```

## Pickup and delivery (shipments)

A *shipment* pairs a pickup point with a delivery point: the same
vehicle must visit the pickup first and then the delivery, in the same
trip. Add shipments with
[`add_shipments()`](https://strategicprojects.github.io/vrpr/reference/add_shipments.md);
they can be mixed freely with regular clients, time windows and every
other feature.

``` r

sh <- tibble::tibble(
  pickup_x   = c(-20, 10, 30),  pickup_y   = c(10, -25, 20),
  delivery_x = c(25, -15, -30), delivery_y = c(-10, 30, -20),
  amount     = c(4, 6, 3)
)

pdp <- vrp_model() |>
  add_depot(0, 0) |>
  add_shipments(sh) |>
  add_vehicle_type(num_available = 2, capacity = 10)

res_pdp <- vrp_solve(pdp, stop = max_iterations(300), seed = 1, display = FALSE)
routes(res_pdp)
#> # A tibble: 6 × 10
#>   route_id depot position activity client shipment  trip vehicle_type
#>      <int> <int>    <int> <chr>     <int>    <int> <int>        <int>
#> 1        1     1        1 pickup       NA        1     1            1
#> 2        1     1        2 pickup       NA        3     1            1
#> 3        1     1        3 delivery     NA        1     1            1
#> 4        1     1        4 pickup       NA        2     1            1
#> 5        1     1        5 delivery     NA        3     1            1
#> 6        1     1        6 delivery     NA        2     1            1
#> # ℹ 2 more variables: start_service <dbl>, wait <dbl>
```

The `activity` column distinguishes pickups from deliveries, and
`shipment` identifies the pair. Optional shipments (`required = FALSE`,
with a `prize`) may be left out;
[`unplanned()`](https://strategicprojects.github.io/vrpr/reference/unplanned.md)
lists them.

## Prize-collecting

Mark clients as optional with `required = FALSE` and give them a
`prize`. The solver visits an optional client only when the prize
offsets the routing cost;
[`unvisited_clients()`](https://strategicprojects.github.io/vrpr/reference/unvisited_clients.md)
lists those left out.
[`add_client_group()`](https://strategicprojects.github.io/vrpr/reference/add_client_group.md)
defines mutually exclusive alternatives.

``` r

pc <- vrp_model() |>
  add_depot(0, 0) |>
  add_clients(tibble::tibble(
    x = c(5, -5, 0, 100, 100),
    y = c(5, -5, 8, 10, -10),
    demand = 10,
    required = c(TRUE, TRUE, TRUE, FALSE, FALSE),
    prize = c(0, 0, 0, 5, 500)
  )) |>
  add_vehicle_type(num_available = 4, capacity = 50)

res_pc <- vrp_solve(pc, stop = max_iterations(500), seed = 1, display = FALSE)
unvisited_clients(res_pc)
#> [1] 4
```

## Reading standard instances

[`read_vrplib()`](https://strategicprojects.github.io/vrpr/reference/read_vrplib.md)
and
[`read_solomon()`](https://strategicprojects.github.io/vrpr/reference/read_solomon.md)
read CVRP/VRPTW instances in the standard VRPLIB/TSPLIB and Solomon
formats, returning a `vrpr_model` ready to solve.

``` r

path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
read_vrplib(path) |>
  vrp_solve(stop = max_iterations(200), seed = 1, display = FALSE) |>
  cost()
#> ✔ Read "sample-n6-k2": 5 clients, 1 depot, capacity 30, 2 vehicles.
#> [1] 68
```

## Other variants

The same data boundary supports more variants:

- **Pickup & delivery / backhaul** – add a `pickup` column to clients;
  the collected load counts toward capacity along the route.
- **Multi-trip** –
  `add_vehicle_type(reload_depots = i, max_reloads = k)` lets a vehicle
  return to a depot to reload and run several trips.

See
[`?add_vehicle_type`](https://strategicprojects.github.io/vrpr/reference/add_vehicle_type.md)
and
[`?add_clients`](https://strategicprojects.github.io/vrpr/reference/add_clients.md)
for the full set of options.
