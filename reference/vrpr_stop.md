# Solver stopping criteria

Control when the iterated local search loop should terminate. Each
function returns a callable object (closure) that the solver invokes
every iteration, receiving the cost of the current best solution and
returning `TRUE` to stop.

## Usage

``` r
max_runtime(seconds)

max_iterations(max_iters)

no_improvement(n)

first_feasible()
```

## Arguments

- seconds:

  Maximum run time, in seconds.

- max_iters:

  Maximum number of iterations.

- n:

  Number of consecutive iterations without improvement before stopping.

## Value

An object of class `vrpr_stop`: a function
`function(best_cost, feasible)` returning `TRUE`/`FALSE`.

## Details

These are the R equivalent of PyVRP's `pyvrp.stop` module.
