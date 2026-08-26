#' Cost evaluator (CostEvaluator)
#'
#' Creates a penalised-cost evaluator. Penalties multiply constraint violations
#' (load, time window, maximum distance) to form the smoothed cost the solver
#' minimises. For a *feasible* solution, the penalised cost equals the objective
#' cost.
#'
#' @param load_penalties Penalty per unit of excess load, per load dimension. A
#'   scalar is recycled across all dimensions.
#' @param tw_penalty Penalty per unit of time warp (time-window violation).
#' @param dist_penalty Penalty per unit of distance above the maximum.
#'
#' @return A `vrpr_cost_evaluator` object.
#' @export
vrp_cost_evaluator <- function(load_penalties = 1, tw_penalty = 1, dist_penalty = 1) {
  if (any(c(load_penalties, tw_penalty, dist_penalty) < 0)) {
    cli::cli_abort("Penalties cannot be negative.")
  }
  ptr <- vrpr_cost_evaluator_create(
    load_penalties = as.double(load_penalties),
    tw_penalty = as.double(tw_penalty),
    dist_penalty = as.double(dist_penalty)
  )
  structure(list(ptr = ptr), class = "vrpr_cost_evaluator")
}

#' Build a solution from explicit routes
#'
#' @param problem_data A [vrp_problem_data()].
#' @param routes A list of integer vectors; each vector is a route given as
#'   *client numbers* (1..n_clients), in visit order. All routes use the first
#'   vehicle type.
#'
#' @return A `vrpr_solution` object.
#' @export
vrp_solution <- function(problem_data, routes) {
  check_problem_data(problem_data)
  if (!is.list(routes)) {
    cli::cli_abort("{.arg routes} must be a list of client vectors.")
  }
  # Client c (1..C) -> CLIENT activity with 0-based index.
  act_routes <- lapply(routes, function(r) {
    r <- as.integer(r)
    list(type = rep(1L, length(r)), idx = r - 1L)
  })
  ptr <- vrpr_solution_from_routes(
    problem_data$ptr, act_routes,
    veh_types = rep(0L, length(act_routes))
  )
  new_solution(ptr)
}

#' Generate a random solution
#'
#' @param problem_data A [vrp_problem_data()].
#' @param seed Integer seed.
#' @return A `vrpr_solution` object.
#' @export
vrp_random_solution <- function(problem_data, seed = 42L) {
  check_problem_data(problem_data)
  rng <- vrpr_rng_create(as.integer(seed))
  ptr <- vrpr_solution_random(problem_data$ptr, rng)
  new_solution(ptr)
}

new_solution <- function(ptr) {
  structure(
    list(ptr = ptr, summary = vrpr_solution_summary(ptr)),
    class = "vrpr_solution"
  )
}

#' Cost of a solution
#'
#' @param solution A [vrp_solution()].
#' @param cost_evaluator A [vrp_cost_evaluator()]. If `NULL`, uses an evaluator
#'   with unit penalties.
#' @return The penalised cost (a `numeric` scalar). For feasible solutions this
#'   is the objective cost; the `feasible` attribute reports feasibility.
#' @export
solution_cost <- function(solution, cost_evaluator = NULL) {
  check_solution(solution)
  if (is.null(cost_evaluator)) cost_evaluator <- vrp_cost_evaluator()
  cost <- vrpr_penalised_cost(cost_evaluator$ptr, solution$ptr)
  structure(cost, feasible = solution$summary$is_feasible)
}

#' Routes of a solution, in long (tidy) format
#'
#' @param x A [vrp_solution()].
#' @param ... Unused.
#' @return A tibble with one row per client, pickup or delivery visit:
#'   `route_id`, `depot` (start depot, 1-based), `position`, `activity`
#'   (`"client"`, `"pickup"` or `"delivery"`), `client` (client number, `NA`
#'   for shipment visits), `shipment` (shipment number, `NA` for client
#'   visits), `trip`, `vehicle_type`, `start_service` (start of service) and
#'   `wait` (waiting time). The last two are only meaningful with time windows
#'   (VRPTW); `depot` varies in the MDVRP; `trip` in multi-trip routes.
#' @export
routes <- function(x, ...) {
  UseMethod("routes")
}

#' @export
routes.vrpr_solution <- function(x, ...) {
  detail <- vrpr_solution_routes(x$ptr)
  empty <- tibble::tibble(
    route_id = integer(), depot = integer(), position = integer(),
    activity = character(), client = integer(), shipment = integer(),
    trip = integer(), vehicle_type = integer(),
    start_service = double(), wait = double()
  )
  if (length(detail) == 0) {
    return(empty)
  }
  rows <- lapply(seq_along(detail), function(i) {
    r <- detail[[i]]
    keep <- r$type != 0L # drop start/reload/end depots from the tidy view
    if (!any(keep)) {
      return(NULL)
    }
    type <- r$type[keep]
    idx <- r$idx[keep]
    tibble::tibble(
      route_id = i,
      depot = r$start_depot + 1L, # 0-based depot -> 1-based
      position = seq_along(idx),
      activity = c("depot", "client", "pickup", "delivery")[type + 1L],
      client = ifelse(type == 1L, idx + 1L, NA_integer_),
      shipment = ifelse(type >= 2L, idx + 1L, NA_integer_),
      trip = r$trip[keep] + 1L,
      vehicle_type = r$vehicle_type + 1L,
      start_service = r$start_time[keep],
      wait = r$wait[keep]
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(empty)
  }
  vctrs::vec_rbind(!!!rows)
}

#' Unplanned activities of a solution
#'
#' Optional clients and shipments that are not part of any route
#' (prize-collecting problems).
#'
#' @param x A [vrp_solution()] or [vrp_solve()] result.
#' @param ... Unused.
#' @return A tibble with columns `activity` (`"client"` or `"pickup"`/
#'   `"delivery"`) and `index` (1-based client or shipment number).
#' @export
unplanned <- function(x, ...) {
  UseMethod("unplanned")
}

#' @export
unplanned.vrpr_solution <- function(x, ...) {
  u <- vrpr_solution_unplanned(x$ptr)
  tibble::tibble(
    activity = c("depot", "client", "pickup", "delivery")[u$type + 1L],
    index = u$idx + 1L
  )
}

#' @export
print.vrpr_solution <- function(x, ...) {
  s <- x$summary
  cli::cli_h1("VRP solution")
  feas <- if (s$is_feasible) cli::col_green("feasible") else cli::col_red("infeasible")
  cli::cli_bullets(c(
    "*" = "{s$num_routes} route{?s} - {s$num_clients} client{?s} visited",
    if (s$num_shipments > 0) c("*" = "{s$num_shipments} shipment{?s} served"),
    "*" = "distance {s$distance} - duration {s$duration}",
    "*" = "status: {feas}{if (s$num_missing_clients > 0) \\
           paste0(' - ', s$num_missing_clients, ' client(s) missing') else ''}"
  ))
  invisible(x)
}

#' @export
print.vrpr_cost_evaluator <- function(x, ...) {
  cli::cli_text("{.cls vrpr_cost_evaluator} penalised-cost evaluator")
  invisible(x)
}

check_problem_data <- function(problem_data, call = rlang::caller_env()) {
  if (!inherits(problem_data, "vrpr_problem_data")) {
    cli::cli_abort(
      "{.arg problem_data} must be a {.cls vrpr_problem_data} \\
       (use {.fn vrp_problem_data}).",
      call = call
    )
  }
}

check_solution <- function(solution, call = rlang::caller_env()) {
  if (!inherits(solution, "vrpr_solution")) {
    cli::cli_abort(
      "{.arg solution} must be a {.cls vrpr_solution}.",
      call = call
    )
  }
}
