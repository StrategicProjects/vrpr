# Read a VRPTW instance in Solomon format

Reads VRPTW instances in Solomon (and Gehring-Homberger) format, with
the `VEHICLE` section (number and capacity) and the `CUSTOMER` table
(coordinates, demand, time window and service time). Customer 0 is the
depot.

## Usage

``` r
read_solomon(path, num_vehicles = NULL)
```

## Arguments

- path:

  Path to the file.

- num_vehicles:

  Number of vehicles; if `NULL`, uses the value from the file.

## Value

A
[`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md)
ready for
[`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md).
