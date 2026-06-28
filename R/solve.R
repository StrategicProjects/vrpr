#' Resolver um modelo VRP
#'
#' Executa o solver de *iterated local search* (ILS) sobre um modelo, usando o
#' núcleo C++ vendorizado do PyVRP.
#'
#' @param model Um [vrp_model()] ou um [vrp_problem_data()] já montado.
#' @param stop Um critério de parada (ver [vrpr_stop]), p.ex. `max_runtime(10)`.
#' @param seed Semente inteira para reprodutibilidade.
#' @param params Parâmetros do solver (ver [ils_params()]).
#' @param display Mostrar progresso via `{cli}`?
#'
#' @return Um objeto `vrpr_result` com a melhor solução, custo, rotas e
#'   estatísticas da execução. Use [cost()], [routes()] e [summary()] para
#'   inspecioná-lo.
#' @export
#' @examples
#' \dontrun{
#' clientes <- tibble::tibble(
#'   x = c(10, 25, 40, 15), y = c(5, 30, 12, 22),
#'   demand = c(10, 15, 8, 12)
#' )
#' res <- vrp_model() |>
#'   add_depot(x = 0, y = 0) |>
#'   add_clients(clientes) |>
#'   add_vehicle_type(num_available = 3, capacity = 50) |>
#'   vrp_solve(stop = max_runtime(2))
#'
#' cost(res)
#' routes(res)
#' }
vrp_solve <- function(model, stop, seed = 42L, params = ils_params(), display = TRUE) {
  if (!inherits(stop, "vrpr_stop")) {
    cli::cli_abort("{.arg stop} deve ser um critério de parada (ver {.help vrpr_stop}).")
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
      "Resolvendo · {s$num_clients} cliente{?s} · {s$num_depots} depósito{?s} · \\
       {s$num_vehicle_types} tipo{?s} de veículo"
    )
  }

  ils <- run_ils(problem_data, stop = stop, seed = seed,
                 params = params, display = display)
  result <- new_result(ils, problem_data)

  if (display) {
    feas <- if (result$is_feasible) "viável" else cli::col_red("nenhuma solução viável")
    cli::cli_alert_success(
      "Concluído em {round(result$runtime, 2)}s · custo \\
       {if (is.finite(result$cost)) round(result$cost) else '—'} · \\
       {result$solution$summary$num_routes} rota{?s} · {feas}"
    )
  }
  result
}
