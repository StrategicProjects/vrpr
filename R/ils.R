# Laço Iterated Local Search (port de IteratedLocalSearch.py do PyVRP).
#
# Descida inicial sobre uma solução aleatória, depois repete: perturba + busca
# local (uma iteração ILS via run_local_search(exhaustive = FALSE)), aceita por
# custo penalizado e mantém a melhor solução viável. As penalidades são ajustadas
# adaptativamente entre as iterações (ver R/penalty.R).

#' Parâmetros do solver ILS
#'
#' @param num_neighbours Tamanho da vizinhança granular (k vizinhos por cliente).
#' @param min_perturbations,max_perturbations Faixa de perturbações por iteração.
#' @param init_load,init_tw,init_dist Penalidades iniciais.
#' @return Uma lista de parâmetros.
#' @export
ils_params <- function(num_neighbours = 20L,
                       min_perturbations = 1L,
                       max_perturbations = 25L,
                       init_load = 20,
                       init_tw = 6,
                       init_dist = 6) {
  list(
    num_neighbours = as.integer(num_neighbours),
    min_perturbations = as.integer(min_perturbations),
    max_perturbations = as.integer(max_perturbations),
    init_load = init_load, init_tw = init_tw, init_dist = init_dist
  )
}

# Objetivo (custo sem penalidades de inviabilidade) de uma solução: custos de
# rota mais os prêmios NÃO coletados (clientes opcionais não visitados). Para
# instâncias sem clientes opcionais, uncollected_prizes = 0.
solution_objective <- function(sol) {
  s <- sol$summary
  s$distance_cost + s$duration_cost + s$fixed_vehicle_cost + s$uncollected_prizes
}

# Uma solução conta como resultado quando é viável e completa.
is_acceptable_solution <- function(sol) {
  isTRUE(sol$summary$is_feasible) && isTRUE(sol$summary$is_complete)
}

run_ils <- function(problem_data, stop, seed = 42L,
                    params = ils_params(), display = TRUE) {
  pm <- new_penalty_manager(
    num_load_dims = problem_data$summary$num_load_dimensions,
    init_load = params$init_load, init_tw = params$init_tw, init_dist = params$init_dist
  )
  ls <- new_local_search(
    problem_data,
    num_neighbours = params$num_neighbours, seed = seed,
    min_perturbations = params$min_perturbations,
    max_perturbations = params$max_perturbations
  )

  start <- Sys.time()
  ce <- pm_cost_evaluator(pm)
  current <- run_local_search(ls, vrp_random_solution(problem_data, seed), ce,
                              exhaustive = TRUE)

  best <- current
  best_obj <- if (is_acceptable_solution(best)) solution_objective(best) else Inf

  iter <- 0L
  if (display) {
    cli::cli_progress_bar(
      format = paste0(
        "{cli::pb_spin} ILS · iteração {iter} · ",
        "melhor {if (is.finite(best_obj)) round(best_obj) else '—'} · ",
        "{cli::pb_elapsed}"
      ),
      clear = FALSE
    )
  }

  repeat {
    iter <- iter + 1L
    ce <- pm_cost_evaluator(pm)
    candidate <- run_local_search(ls, current, ce, exhaustive = FALSE, shuffle = TRUE)

    cs <- candidate$summary
    pm_register(pm, !cs$has_excess_load, !cs$has_time_warp, !cs$has_excess_distance)

    # Aceitação gulosa sob as penalidades correntes.
    if (as.numeric(solution_cost(candidate, ce)) <=
        as.numeric(solution_cost(current, ce))) {
      current <- candidate
    }

    if (is_acceptable_solution(candidate)) {
      obj <- solution_objective(candidate)
      if (obj < best_obj) {
        best <- candidate
        best_obj <- obj
      }
    }

    if (display) cli::cli_progress_update()
    if (isTRUE(stop(best_cost = best_obj, feasible = is.finite(best_obj)))) break
  }
  if (display) cli::cli_progress_done()

  list(
    best = best,
    cost = best_obj,
    is_feasible = is.finite(best_obj),
    iterations = iter,
    runtime = as.numeric(difftime(Sys.time(), start, units = "secs"))
  )
}
