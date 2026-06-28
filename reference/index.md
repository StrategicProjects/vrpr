# Package index

## Modelling

Build a VRP model by piping together depots, clients and vehicle types.

- [`vrp_model()`](https://strategicprojects.github.io/vrpr/reference/vrp_model.md)
  : Build a vehicle routing (VRP) model
- [`add_depot()`](https://strategicprojects.github.io/vrpr/reference/add_depot.md)
  : Add a depot to the model
- [`add_clients()`](https://strategicprojects.github.io/vrpr/reference/add_clients.md)
  : Add clients to the model
- [`add_vehicle_type()`](https://strategicprojects.github.io/vrpr/reference/add_vehicle_type.md)
  : Add a vehicle type to the model
- [`add_client_group()`](https://strategicprojects.github.io/vrpr/reference/add_client_group.md)
  : Add a mutually exclusive group of clients

## Solving

Run the iterated local search solver and control when it stops.

- [`vrp_solve()`](https://strategicprojects.github.io/vrpr/reference/vrp_solve.md)
  : Solve a VRP model
- [`ils_params()`](https://strategicprojects.github.io/vrpr/reference/ils_params.md)
  : ILS solver parameters
- [`max_runtime()`](https://strategicprojects.github.io/vrpr/reference/vrpr_stop.md)
  [`max_iterations()`](https://strategicprojects.github.io/vrpr/reference/vrpr_stop.md)
  [`no_improvement()`](https://strategicprojects.github.io/vrpr/reference/vrpr_stop.md)
  [`first_feasible()`](https://strategicprojects.github.io/vrpr/reference/vrpr_stop.md)
  : Solver stopping criteria

## Results

Inspect and visualise a solution.

- [`cost()`](https://strategicprojects.github.io/vrpr/reference/cost.md)
  : Cost of a result or solution
- [`routes()`](https://strategicprojects.github.io/vrpr/reference/routes.md)
  : Routes of a solution, in long (tidy) format
- [`summary(`*`<vrpr_result>`*`)`](https://strategicprojects.github.io/vrpr/reference/summary.vrpr_result.md)
  : One-row summary of a result (tibble)
- [`unvisited_clients()`](https://strategicprojects.github.io/vrpr/reference/unvisited_clients.md)
  : Unvisited optional clients
- [`plot(`*`<vrpr_result>`*`)`](https://strategicprojects.github.io/vrpr/reference/plot.vrpr_result.md)
  : Plot the solution of a VRP result
- [`plot(`*`<vrpr_model>`*`)`](https://strategicprojects.github.io/vrpr/reference/plot.vrpr_model.md)
  : Plot a VRP model (depots and clients only)

## Reading instances

Read standard VRPLIB and Solomon instance files.

- [`read_vrplib()`](https://strategicprojects.github.io/vrpr/reference/read_vrplib.md)
  : Read an instance in VRPLIB / TSPLIB format
- [`read_solomon()`](https://strategicprojects.github.io/vrpr/reference/read_solomon.md)
  : Read a VRPTW instance in Solomon format

## Lower-level building blocks

Direct access to the problem data, solutions and cost evaluator.

- [`vrp_problem_data()`](https://strategicprojects.github.io/vrpr/reference/vrp_problem_data.md)
  : Assemble the problem data (ProblemData) from a model
- [`vrp_solution()`](https://strategicprojects.github.io/vrpr/reference/vrp_solution.md)
  : Build a solution from explicit routes
- [`vrp_random_solution()`](https://strategicprojects.github.io/vrpr/reference/vrp_random_solution.md)
  : Generate a random solution
- [`vrp_cost_evaluator()`](https://strategicprojects.github.io/vrpr/reference/vrp_cost_evaluator.md)
  : Cost evaluator (CostEvaluator)
- [`solution_cost()`](https://strategicprojects.github.io/vrpr/reference/solution_cost.md)
  : Cost of a solution
