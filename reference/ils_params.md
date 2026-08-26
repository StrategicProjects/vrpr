# ILS solver parameters

ILS solver parameters

## Usage

``` r
ils_params(
  num_neighbours = 50L,
  min_perturbations = 1L,
  max_perturbations = 25L,
  history_length = 300L,
  num_iters_no_improvement = 150000L,
  exhaustive_on_best = TRUE
)
```

## Arguments

- num_neighbours:

  Granular neighbourhood size (activities per neighbourhood). Default
  50, as in PyVRP.

- min_perturbations, max_perturbations:

  Range of perturbations per iteration.

- history_length:

  Length of the late-acceptance history (\> 0). Default 300, as in
  PyVRP.

- num_iters_no_improvement:

  Iterations without improvement before restarting from the best.

- exhaustive_on_best:

  Refine each new best with an exhaustive search?

## Value

A list of parameters.
