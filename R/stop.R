#' Critérios de parada do solver
#'
#' Controlam quando o laço de *iterated local search* deve terminar. Cada função
#' devolve um objeto chamável (closure) que o solver invoca a cada iteração,
#' recebendo o custo da melhor solução corrente e retornando `TRUE` para parar.
#'
#' São o equivalente R do módulo `pyvrp.stop` do PyVRP.
#'
#' @param seconds Tempo máximo de execução, em segundos.
#' @param max_iters Número máximo de iterações.
#' @param n Número de iterações consecutivas sem melhora antes de parar.
#'
#' @return Um objeto de classe `vrpr_stop`: uma função
#'   `function(best_cost, feasible)` que retorna `TRUE`/`FALSE`.
#' @name vrpr_stop
NULL

new_stop <- function(fn, kind) {
  structure(fn, class = c(paste0("vrpr_stop_", kind), "vrpr_stop", "function"))
}

#' @rdname vrpr_stop
#' @export
max_runtime <- function(seconds) {
  if (!rlang::is_scalar_double(seconds) && !rlang::is_scalar_integerish(seconds)) {
    cli::cli_abort("{.arg seconds} deve ser um número escalar.")
  }
  if (seconds <= 0) cli::cli_abort("{.arg seconds} deve ser positivo.")

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
    cli::cli_abort("{.arg max_iters} deve ser um inteiro positivo.")
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
    cli::cli_abort("{.arg n} deve ser um inteiro positivo.")
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
  cli::cli_text("{.cls vrpr_stop} critério de parada: {.field {kind}}")
  invisible(x)
}
