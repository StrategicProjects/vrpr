#' Solve a VRP model
#'
#' Runs the iterated local search (ILS) solver on a model, using PyVRP's vendored
#' C++ core.
#'
#' @param model A [vrp_model()] or an already-assembled [vrp_problem_data()].
#' @param stop A stopping criterion (see [vrpr_stop]), e.g. `max_runtime(10)`.
#' @param seed Integer seed for reproducibility.
#' @param params Solver parameters (see [ils_params()]).
#' @param display Show progress via `{cli}`?
#'
#' @return A `vrpr_result` object with the best solution, cost, routes and run
#'   statistics. Use [cost()], [routes()] and [summary()] to inspect it.
#' @export
#' @examples
#' \dontrun{
#' clients <- tibble::tibble(
#'   x = c(10, 25, 40, 15), y = c(5, 30, 12, 22),
#'   demand = c(10, 15, 8, 12)
#' )
#' res <- vrp_model() |>
#'   add_depot(x = 0, y = 0) |>
#'   add_clients(clients) |>
#'   add_vehicle_type(num_available = 3, capacity = 50) |>
#'   vrp_solve(stop = max_runtime(2))
#'
#' cost(res)
#' routes(res)
#' }
vrp_solve <- function(model, stop, seed = 42L, params = ils_params(), display = TRUE) {
  if (!inherits(stop, "vrpr_stop")) {
    cli::cli_abort("{.arg stop} must be a stopping criterion (see {.help vrpr_stop}).")
  }

  problem_data <- if (inherits(model, "vrpr_problem_data")) {
    model
  } else {
    check_model(model)
    vrp_problem_data(model)
  }

  s <- problem_data$summary
  if (display) {
    cli::cli_alert_info(
      "Solving - {s$num_clients} client{?s} - {s$num_depots} depot{?s} - \\
       {s$num_vehicle_types} vehicle type{?s}"
    )
  }

  ils <- run_ils(problem_data, stop = stop, seed = seed,
                 params = params, display = display)
  result <- new_result(ils, problem_data)

  if (display) {
    feas <- if (result$is_feasible) "feasible" else cli::col_red("no feasible solution")
    cli::cli_alert_success(
      "Done in {round(result$runtime, 2)}s - cost \\
       {if (is.finite(result$cost)) round(result$cost) else '-'} - \\
       {result$solution$summary$num_routes} route{?s} - {feas}"
    )
  }
  result
}
