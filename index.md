# vrpr

> PyVRP for R — a production-grade vehicle routing problem (VRP) solver.

`vrpr` ports the [PyVRP](https://github.com/PyVRP/PyVRP) solver (a
high-performance, MIT-licensed C++ core) to an idiomatic **R** package
in the **tidyverse** style: a pipe-friendly API, data in tibbles,
logging via [`{cli}`](https://cli.r-lib.org), and the C++ core rewired
with [`{cpp11}`](https://cpp11.r-lib.org) — with **no Python runtime
dependency**.

It fills a real gap in the R ecosystem: there are `ompr`, `ROI`,
`lpSolve`, `igraph` and `dodgr`, but no modern, strong, friendly solver
for production VRP.

## Status

🚧 **Early development** — **all PyVRP variants** already solve
end-to-end: CVRP, VRPTW (time windows), heterogeneous fleet, MDVRP
(multiple depots), prize-collecting (optional clients + groups),
simultaneous pickup and delivery / backhaul, and multi-trip. Next:
vignettes, CI, CRAN.

**Parity with PyVRP** is verified (see `tools/benchmark/`): the
objective is identical bit for bit and, on the X-n101-k25 instance
(optimum 27591), both reach the optimum in 10 s.

``` r

library(vrpr)

clients <- tibble::tibble(
  x = c(10, 25, 40, 15), y = c(5, 30, 12, 22),
  demand = c(10, 15, 8, 12)
)

res <- vrp_model() |>
  add_depot(x = 0, y = 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 3, capacity = 50) |>
  vrp_solve(stop = max_runtime(2))

cost(res)      # objective cost
routes(res)    # tibble: route_id, position, client, vehicle_type
summary(res)   # one-row summary
```

## Variants

- **VRPTW:** add `tw_early`, `tw_late`, `service` to clients;
  [`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
  reports `start_service` and `wait` per visit.
- **Heterogeneous fleet:** call
  [`add_vehicle_type()`](https://strategicprojects.github.io/vrpr/reference/add_vehicle_type.md)
  several times with different capacities, costs (`fixed_cost`,
  `unit_distance_cost`) and shifts.
- **MDVRP:** call
  [`add_depot()`](https://strategicprojects.github.io/vrpr/reference/add_depot.md)
  several times and use `add_vehicle_type(depot = i)` to base each
  vehicle type at a depot;
  [`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
  reports the `depot` column.
- **Prize-collecting:** mark clients with `required = FALSE` and
  `prize`; the solver decides which to visit.
  [`add_client_group()`](https://strategicprojects.github.io/vrpr/reference/add_client_group.md)
  defines mutually exclusive alternatives. See the skipped ones with
  [`unvisited_clients()`](https://strategicprojects.github.io/vrpr/reference/unvisited_clients.md).
- **Pickup & delivery / backhaul:** add a `pickup` column to clients
  (the collected load counts toward capacity along the route).
- **Multi-trip:** `add_vehicle_type(reload_depots = i, max_reloads = k)`
  lets a vehicle return to a depot to reload and make several trips
  (`summary()$num_trips`).

### Read standard instances

``` r

m <- read_vrplib(system.file("extdata", "sample-n6-k2.vrp", package = "vrpr"))
m <- read_solomon(system.file("extdata", "sample-solomon.txt", package = "vrpr"))
res <- m |> vrp_solve(stop = max_runtime(5))
```

[`read_vrplib()`](https://strategicprojects.github.io/vrpr/reference/read_vrplib.md)
reads CVRP/VRPTW in VRPLIB/TSPLIB format (EUC_2D);
[`read_solomon()`](https://strategicprojects.github.io/vrpr/reference/read_solomon.md)
reads VRPTW in Solomon format. Both return a `vrpr_model`.

### Visualise

``` r

plot(res)   # depots, clients and routes (one colour per route) with {ggplot2}
```

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) (on a result or
a model) draws depots (squares), clients (points; unvisited optional
ones appear hollow) and the coloured routes. Requires
[ggplot2](https://ggplot2.tidyverse.org).

## Algorithm

Iterated Local Search (ILS) — inherited from PyVRP v0.13.x.

## License

MIT. Derived from PyVRP (© PyVRP authors), whose copyright is preserved
(see `inst/COPYRIGHTS`).
