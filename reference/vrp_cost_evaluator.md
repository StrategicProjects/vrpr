# Cost evaluator (CostEvaluator)

Creates a penalised-cost evaluator. Penalties multiply constraint
violations (load, time window, maximum distance) to form the smoothed
cost the solver minimises. For a *feasible* solution, the penalised cost
equals the objective cost.

## Usage

``` r
vrp_cost_evaluator(load_penalties = 1, tw_penalty = 1, dist_penalty = 1)
```

## Arguments

- load_penalties:

  Penalty per unit of excess load, per load dimension. A scalar is
  recycled across all dimensions.

- tw_penalty:

  Penalty per unit of time warp (time-window violation).

- dist_penalty:

  Penalty per unit of distance above the maximum.

## Value

A `vrpr_cost_evaluator` object.
