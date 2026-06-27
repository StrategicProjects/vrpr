#' Resolver um modelo VRP
#'
#' Executa o solver de *iterated local search* (ILS) sobre um `vrpr_model`,
#' usando o núcleo C++ vendorizado do PyVRP.
#'
#' @details
#' **Fase 1 — em construção.** O laço ILS, o `PenaltyManager` e a montagem do
#' `ProblemData` em C++ ainda estão sendo ligados (ver `plano.md`). Por ora esta
#' função valida os argumentos e sinaliza claramente o que falta.
#'
#' @param model Um [vrp_model()].
#' @param stop Um critério de parada (ver [vrpr_stop]), p.ex. `max_runtime(10)`.
#' @param seed Semente inteira para reprodutibilidade.
#' @param display Mostrar progresso via `{cli}`?
#'
#' @return (Quando implementado) um objeto `vrpr_result` com a melhor solução,
#'   custo, rotas e estatísticas.
#' @export
vrp_solve <- function(model, stop, seed = 42L, display = TRUE) {
  check_model(model)
  if (!inherits(stop, "vrpr_stop")) {
    cli::cli_abort("{.arg stop} deve ser um critério de parada (ver {.help vrpr_stop}).")
  }
  if (nrow(model$depots) == 0) {
    cli::cli_abort("O modelo precisa de ao menos um depósito.")
  }
  if (nrow(model$vehicle_types) == 0) {
    cli::cli_abort("O modelo precisa de ao menos um tipo de veículo.")
  }

  rlang::abort(
    class = "vrpr_not_implemented",
    message = c(
      "O solver C++ ainda não está ligado (Fase 1 em andamento).",
      "i" = "Estrutura do modelo e critérios de parada já funcionam.",
      "i" = "Próximo passo: ligar o ProblemData/ILS via cpp11 (ver plano.md)."
    )
  )
}
