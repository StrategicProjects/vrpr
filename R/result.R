# Resultado de vrp_solve(): a melhor solução + metadados da execução.

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

#' Custo de um resultado ou solução
#'
#' @param x Um [vrp_solve()] resultado ou uma [vrp_solution()].
#' @param ... Não usado.
#' @return O custo objetivo (escalar `numeric`); `Inf` se nenhuma solução viável
#'   foi encontrada.
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

#' Clientes opcionais não visitados
#'
#' Em problemas *prize-collecting*, clientes com `required = FALSE` podem ficar
#' de fora se o prêmio não compensar o custo de roteirização.
#'
#' @param x Um [vrp_solve()] resultado.
#' @param ... Não usado.
#' @return Vetor inteiro com os números dos clientes (1-based) não visitados.
#' @export
unvisited_clients <- function(x, ...) {
  UseMethod("unvisited_clients")
}

#' @export
unvisited_clients.vrpr_result <- function(x, ...) {
  total <- x$problem_data$summary$num_clients
  setdiff(seq_len(total), routes(x$solution)$client)
}

#' Resumo de um resultado, em uma linha (tibble)
#'
#' @param object Um [vrp_solve()] resultado.
#' @param ... Não usado.
#' @return Um tibble de uma linha com custo, viabilidade, nº de rotas, iterações
#'   e tempo.
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
  cli::cli_h1("resultado vrpr")
  feas <- if (x$is_feasible) cli::col_green("viável") else cli::col_red("inviável")
  cli::cli_bullets(c(
    "*" = "custo {if (is.finite(x$cost)) round(x$cost) else '—'} · {feas}",
    "*" = "{s$num_routes} rota{?s} · {s$num_clients} cliente{?s}",
    "*" = "{x$iterations} iteraç{?ão/ões} · {round(x$runtime, 2)}s"
  ))
  invisible(x)
}
