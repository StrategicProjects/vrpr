# Result of vrp_solve(): the best solution + run metadata.

new_result <- function(ils, problem_data) {
  structure(
    list(
      solution = ils$best,
      cost = ils$cost,
      is_feasible = ils$is_feasible,
      iterations = ils$iterations,
      runtime = ils$runtime,
      problem_data = problem_data
    ),
    class = "vrpr_result"
  )
}

#' Cost of a result or solution
#'
#' @param x A [vrp_solve()] result or a [vrp_solution()].
#' @param ... Unused.
#' @return The objective cost (a `numeric` scalar); `Inf` if no feasible solution
#'   was found.
#' @export
cost <- function(x, ...) {
  UseMethod("cost")
}

#' @export
cost.vrpr_result <- function(x, ...) x$cost

#' @export
cost.vrpr_solution <- function(x, ...) solution_objective(x)

#' @export
routes.vrpr_result <- function(x, ...) routes(x$solution, ...)

#' Unvisited optional clients
#'
#' In prize-collecting problems, clients with `required = FALSE` may be left out
#' if the prize does not offset the routing cost.
#'
#' @param x A [vrp_solve()] result.
#' @param ... Unused.
#' @return An integer vector of the (1-based) client numbers not visited.
#' @export
unvisited_clients <- function(x, ...) {
  UseMethod("unvisited_clients")
}

#' @export
unvisited_clients.vrpr_result <- function(x, ...) {
  total <- x$problem_data$summary$num_clients
  setdiff(seq_len(total), routes(x$solution)$client)
}

#' One-row summary of a result (tibble)
#'
#' @param object A [vrp_solve()] result.
#' @param ... Unused.
#' @return A one-row tibble with cost, feasibility, number of routes, iterations
#'   and runtime.
#' @export
summary.vrpr_result <- function(object, ...) {
  s <- object$solution$summary
  tibble::tibble(
    cost = object$cost,
    is_feasible = object$is_feasible,
    num_routes = s$num_routes,
    num_trips = s$num_trips,
    num_clients = s$num_clients,
    distance = s$distance,
    iterations = object$iterations,
    runtime = object$runtime
  )
}

#' @export
print.vrpr_result <- function(x, ...) {
  s <- x$solution$summary
  cli::cli_h1("vrpr result")
  feas <- if (x$is_feasible) cli::col_green("feasible") else cli::col_red("infeasible")
  cli::cli_bullets(c(
    "*" = "cost {if (is.finite(x$cost)) round(x$cost) else '-'} - {feas}",
    "*" = "{s$num_routes} route{?s} - {s$num_clients} client{?s}",
    "*" = "{x$iterations} iteration{?s} - {round(x$runtime, 2)}s"
  ))
  invisible(x)
}
