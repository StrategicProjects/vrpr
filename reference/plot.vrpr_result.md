# Plot the solution of a VRP result

Draws depots, clients and the routes (one colour per route) over the
instance coordinates. Unvisited optional clients (prize-collecting)
appear as hollow circles.

## Usage

``` r
# S3 method for class 'vrpr_result'
plot(x, show_clients = TRUE, ...)
```

## Arguments

- x:

  A
  [`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md)
  result.

- show_clients:

  Reserved; clients are always drawn.

- ...:

  Unused.

## Value

A `ggplot` object.
