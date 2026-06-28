# Read an instance in VRPLIB / TSPLIB format

Reads CVRP (and VRPTW) instances in VRPLIB/CVRPLIB format (extended
TSPLIB), such as the X set by Uchoa et al. Supports Euclidean
coordinates (`EDGE_WEIGHT_TYPE : EUC_2D`); time-window and service-time
sections are read when present.

## Usage

``` r
read_vrplib(path, num_vehicles = NULL)
```

## Arguments

- path:

  Path to the `.vrp` file.

- num_vehicles:

  Number of available vehicles. If `NULL`, uses the `VEHICLES`/`TRUCKS`
  field, the `-k<n>` suffix in the name, or – as a last resort – the
  number of clients (always feasible).

## Value

A
[`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md)
ready for
[`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md).
