#' Solver stopping criteria
#'
#' Control when the iterated local search loop should terminate. Each function
#' returns a callable object (closure) that the solver invokes every iteration,
#' receiving the cost of the current best solution and returning `TRUE` to stop.
#'
#' These are the R equivalent of PyVRP's `pyvrp.stop` module.
#'
#' @param seconds Maximum run time, in seconds.
#' @param max_iters Maximum number of iterations.
#' @param n Number of consecutive iterations without improvement before stopping.
#'
#' @return An object of class `vrpr_stop`: a function
#'   `function(best_cost, feasible)` returning `TRUE`/`FALSE`.
#' @name vrpr_stop
NULL

new_stop <- function(fn, kind) {
  structure(fn, class = c(paste0("vrpr_stop_", kind), "vrpr_stop", "function"))
}

#' @rdname vrpr_stop
#' @export
max_runtime <- function(seconds) {
  if (!rlang::is_scalar_double(seconds) && !rlang::is_scalar_integerish(seconds)) {
    cli::cli_abort("{.arg seconds} must be a scalar number.")
  }
  if (seconds <= 0) cli::cli_abort("{.arg seconds} must be positive.")

  start <- NULL
  new_stop(function(best_cost = NULL, feasible = NULL) {
    now <- as.numeric(Sys.time())
    if (is.null(start)) start <<- now
    (now - start) >= seconds
  }, "max_runtime")
}

#' @rdname vrpr_stop
#' @export
max_iterations <- function(max_iters) {
  if (!rlang::is_scalar_integerish(max_iters) || max_iters <= 0) {
    cli::cli_abort("{.arg max_iters} must be a positive integer.")
  }
  seen <- 0L
  new_stop(function(best_cost = NULL, feasible = NULL) {
    seen <<- seen + 1L
    seen >= max_iters
  }, "max_iterations")
}

#' @rdname vrpr_stop
#' @export
no_improvement <- function(n) {
  if (!rlang::is_scalar_integerish(n) || n <= 0) {
    cli::cli_abort("{.arg n} must be a positive integer.")
  }
  best <- Inf
  since <- 0L
  new_stop(function(best_cost = NULL, feasible = NULL) {
    if (is.null(best_cost)) return(FALSE)
    if (best_cost < best) {
      best <<- best_cost
      since <<- 0L
    } else {
      since <<- since + 1L
    }
    since >= n
  }, "no_improvement")
}

#' @rdname vrpr_stop
#' @export
first_feasible <- function() {
  new_stop(function(best_cost = NULL, feasible = NULL) {
    isTRUE(feasible)
  }, "first_feasible")
}

#' @export
print.vrpr_stop <- function(x, ...) {
  kind <- sub("^vrpr_stop_", "", setdiff(class(x), c("vrpr_stop", "function"))[1])
  cli::cli_text("{.cls vrpr_stop} stopping criterion: {.field {kind}}")
  invisible(x)
}
