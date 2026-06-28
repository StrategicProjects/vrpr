# ILS solver parameters

ILS solver parameters

## Usage

``` r
ils_params(
  num_neighbours = 20L,
  min_perturbations = 1L,
  max_perturbations = 25L,
  init_load = 20,
  init_tw = 6,
  init_dist = 6,
  history_length = 300L,
  num_iters_no_improvement = 150000L,
  exhaustive_on_best = TRUE
)
```

## Arguments

- num_neighbours:

  Granular neighbourhood size (k neighbours per client).

- min_perturbations, max_perturbations:

  Range of perturbations per iteration.

- init_load, init_tw, init_dist:

  Initial penalties.

- history_length:

  Length of the late-acceptance history (\> 0). Default 300, as in
  PyVRP.

- num_iters_no_improvement:

  Iterations without improvement before restarting from the best.

- exhaustive_on_best:

  Refine each new best with an exhaustive search?

## Value

A list of parameters.
