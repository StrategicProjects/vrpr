#' Avaliador de custo (CostEvaluator)
#'
#' Cria um avaliador de custo penalizado. Penalidades multiplicam as violações
#' de restrições (carga, janela de tempo, distância máxima) para formar o custo
#' suavizado que o solver minimiza. Para uma solução *viável*, o custo penalizado
#' coincide com o custo objetivo.
#'
#' @param load_penalties Penalidade por unidade de carga em excesso, por dimensão
#'   de carga. Escalar é reciclado para todas as dimensões.
#' @param tw_penalty Penalidade por unidade de *time warp* (violação de janela).
#' @param dist_penalty Penalidade por unidade de distância acima do máximo.
#'
#' @return Um objeto `vrpr_cost_evaluator`.
#' @export
vrp_cost_evaluator <- function(load_penalties = 1, tw_penalty = 1, dist_penalty = 1) {
  if (any(c(load_penalties, tw_penalty, dist_penalty) < 0)) {
    cli::cli_abort("As penalidades não podem ser negativas.")
  }
  ptr <- vrpr_cost_evaluator_create(
    load_penalties = as.double(load_penalties),
    tw_penalty = as.double(tw_penalty),
    dist_penalty = as.double(dist_penalty)
  )
  structure(list(ptr = ptr), class = "vrpr_cost_evaluator")
}

#' Construir uma solução a partir de rotas explícitas
#'
#' @param problem_data Um [vrp_problem_data()].
#' @param routes Lista de vetores inteiros; cada vetor é uma rota dada como
#'   *números de cliente* (1..n_clientes), na ordem de visita. Todas as rotas
#'   usam o primeiro tipo de veículo.
#'
#' @return Um objeto `vrpr_solution`.
#' @export
vrp_solution <- function(problem_data, routes) {
  check_problem_data(problem_data)
  if (!is.list(routes)) {
    cli::cli_abort("{.arg routes} deve ser uma lista de vetores de clientes.")
  }
  n_depots <- problem_data$summary$num_depots
  # Cliente c (1..C) -> índice de localização (depósitos primeiro).
  loc_routes <- lapply(routes, function(r) as.integer(n_depots + as.integer(r) - 1L))
  ptr <- vrpr_solution_from_routes(problem_data$ptr, loc_routes)
  new_solution(ptr, n_depots)
}

#' Gerar uma solução aleatória
#'
#' @param problem_data Um [vrp_problem_data()].
#' @param seed Semente inteira.
#' @return Um objeto `vrpr_solution`.
#' @export
vrp_random_solution <- function(problem_data, seed = 42L) {
  check_problem_data(problem_data)
  rng <- vrpr_rng_create(as.integer(seed))
  ptr <- vrpr_solution_random(problem_data$ptr, rng)
  new_solution(ptr, problem_data$summary$num_depots)
}

new_solution <- function(ptr, n_depots) {
  structure(
    list(ptr = ptr, n_depots = n_depots, summary = vrpr_solution_summary(ptr)),
    class = "vrpr_solution"
  )
}

#' Custo de uma solução
#'
#' @param solution Um [vrp_solution()].
#' @param cost_evaluator Um [vrp_cost_evaluator()]. Se `NULL`, usa um avaliador
#'   com penalidades unitárias.
#' @return O custo penalizado (escalar `numeric`). Para soluções viáveis é o
#'   custo objetivo; o atributo `feasible` indica a viabilidade.
#' @export
solution_cost <- function(solution, cost_evaluator = NULL) {
  check_solution(solution)
  if (is.null(cost_evaluator)) cost_evaluator <- vrp_cost_evaluator()
  cost <- vrpr_penalised_cost(cost_evaluator$ptr, solution$ptr)
  structure(cost, feasible = solution$summary$is_feasible)
}

#' Rotas de uma solução, em formato longo (tidy)
#'
#' @param x Um [vrp_solution()].
#' @param ... Não usado.
#' @return Um tibble com uma linha por visita: `route_id`, `position`, `client`,
#'   `vehicle_type`.
#' @export
routes <- function(x, ...) {
  UseMethod("routes")
}

#' @export
routes.vrpr_solution <- function(x, ...) {
  detail <- vrpr_solution_routes(x$ptr)
  if (length(detail) == 0) {
    return(tibble::tibble(
      route_id = integer(), position = integer(),
      client = integer(), vehicle_type = integer()
    ))
  }
  rows <- lapply(seq_along(detail), function(i) {
    r <- detail[[i]]
    # Índice de localização -> número do cliente.
    clients <- r$visits - x$n_depots + 1L
    tibble::tibble(
      route_id = i,
      position = seq_along(clients),
      client = as.integer(clients),
      vehicle_type = r$vehicle_type + 1L
    )
  })
  vctrs::vec_rbind(!!!rows)
}

#' @export
print.vrpr_solution <- function(x, ...) {
  s <- x$summary
  cli::cli_h1("solução VRP")
  feas <- if (s$is_feasible) cli::col_green("viável") else cli::col_red("inviável")
  cli::cli_bullets(c(
    "*" = "{s$num_routes} rota{?s} · {s$num_clients} cliente{?s} visitado{?s}",
    "*" = "distância {s$distance} · duração {s$duration}",
    "*" = "situação: {feas}{if (s$num_missing_clients > 0) \\
           paste0(' · ', s$num_missing_clients, ' cliente(s) faltando') else ''}"
  ))
  invisible(x)
}

#' @export
print.vrpr_cost_evaluator <- function(x, ...) {
  cli::cli_text("{.cls vrpr_cost_evaluator} avaliador de custo penalizado")
  invisible(x)
}

check_problem_data <- function(problem_data, call = rlang::caller_env()) {
  if (!inherits(problem_data, "vrpr_problem_data")) {
    cli::cli_abort(
      "{.arg problem_data} deve ser um {.cls vrpr_problem_data} \\
       (use {.fn vrp_problem_data}).",
      call = call
    )
  }
}

check_solution <- function(solution, call = rlang::caller_env()) {
  if (!inherits(solution, "vrpr_solution")) {
    cli::cli_abort(
      "{.arg solution} deve ser um {.cls vrpr_solution}.",
      call = call
    )
  }
}
