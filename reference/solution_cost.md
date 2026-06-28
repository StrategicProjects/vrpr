# Cost of a solution

Cost of a solution

## Usage

``` r
solution_cost(solution, cost_evaluator = NULL)
```

## Arguments

- solution:

  A
  [`vrp_solution()`](https://strategicprojects.github.io/vrpr/reference/vrp_solution.md).

- cost_evaluator:

  A
  [`vrp_cost_evaluator()`](https://strategicprojects.github.io/vrpr/reference/vrp_cost_evaluator.md).
  If `NULL`, uses an evaluator with unit penalties.

## Value

The penalised cost (a `numeric` scalar). For feasible solutions this is
the objective cost; the `feasible` attribute reports feasibility.
