# Unvisited optional clients

In prize-collecting problems, clients with `required = FALSE` may be
left out if the prize does not offset the routing cost.

## Usage

``` r
unvisited_clients(x, ...)
```

## Arguments

- x:

  A
  [`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md)
  result.

- ...:

  Unused.

## Value

An integer vector of the (1-based) client numbers not visited.
