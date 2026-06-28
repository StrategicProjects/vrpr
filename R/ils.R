# Laço Iterated Local Search (port fiel de IteratedLocalSearch.py do PyVRP).
#
# Usa Late Acceptance Hill-Climbing (Burke & Bykov, 2017): aceita o candidato se
# ele melhora o custo de `history_length` iterações atrás OU o custo corrente.
# Após `num_iters_no_improvement` iterações sem melhora, reinicia do melhor.
# Ao encontrar um novo melhor, faz uma busca exaustiva (sem perturbação) para
# refiná-lo. As penalidades são ajustadas adaptativamente entre iterações.

#' Parâmetros do solver ILS
#'
#' @param num_neighbours Tamanho da vizinhança granular (k vizinhos por cliente).
#' @param min_perturbations,max_perturbations Faixa de perturbações por iteração.
#' @param init_load,init_tw,init_dist Penalidades iniciais.
#' @param history_length Comprimento do histórico do *late acceptance* (> 0).
#'   Default 300, como no PyVRP.
#' @param num_iters_no_improvement Iterações sem melhora antes de reiniciar do melhor.
#' @param exhaustive_on_best Refinar cada novo melhor com uma busca exaustiva?
#' @return Uma lista de parâmetros.
#' @export
ils_params <- function(num_neighbours = 20L,
                       min_perturbations = 1L,
                       max_perturbations = 25L,
                       init_load = 20,
                       init_tw = 6,
                       init_dist = 6,
                       history_length = 300L,
                       num_iters_no_improvement = 150000L,
                       exhaustive_on_best = TRUE) {
  list(
    num_neighbours = as.integer(num_neighbours),
    min_perturbations = as.integer(min_perturbations),
    max_perturbations = as.integer(max_perturbations),
    init_load = init_load, init_tw = init_tw, init_dist = init_dist,
    history_length = as.integer(history_length),
    num_iters_no_improvement = as.integer(num_iters_no_improvement),
    exhaustive_on_best = isTRUE(exhaustive_on_best)
  )
}

# Objetivo (custo sem penalidades de inviabilidade): custos de rota + prêmios não
# coletados. Para instâncias sem clientes opcionais, uncollected_prizes = 0.
solution_objective <- function(sol) {
  s <- sol$summary
  s$distance_cost + s$duration_cost + s$fixed_vehicle_cost + s$uncollected_prizes
}

# Custo "verdadeiro" no estilo do CostEvaluator::cost do PyVRP: o objetivo se
# viável, senão infinito (de modo que soluções inviáveis nunca viram o melhor).
feasible_cost <- function(sol) {
  if (isTRUE(sol$summary$is_feasible)) solution_objective(sol) else Inf
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
  init <- run_local_search(ls, vrp_random_solution(problem_data, seed), ce,
                           exhaustive = TRUE)
  best <- curr <- init

  # Ring buffer de soluções para o late acceptance.
  hlen <- max(1L, params$history_length)
  buf <- vector("list", hlen)
  ridx <- 0L
  ring_peek <- function() buf[[ridx %% hlen + 1L]]
  ring_append <- function(v) {
    buf[[ridx %% hlen + 1L]] <<- v
    ridx <<- ridx + 1L
  }
  ring_skip <- function() ridx <<- ridx + 1L
  ring_clear <- function() {
    buf <<- vector("list", hlen)
    ridx <<- 0L
  }

  # Custo penalizado de uma solução sob o avaliador corrente.
  pen <- function(sol) as.numeric(solution_cost(sol, ce))

  iters <- 0L
  iters_no_improve <- 0L
  best_true <- feasible_cost(best)

  if (display) {
    cli::cli_progress_bar(
      format = paste0(
        "{cli::pb_spin} ILS · iteração {iters} · ",
        "melhor {if (is.finite(best_true)) round(best_true) else '—'} · ",
        "{cli::pb_elapsed}"
      ),
      clear = FALSE
    )
  }

  repeat {
    iters <- iters + 1L

    if (iters_no_improve == params$num_iters_no_improvement) {
      ring_clear()
      curr <- best
      iters_no_improve <- 0L
    }

    ce <- pm_cost_evaluator(pm)
    cand <- run_local_search(ls, curr, ce, exhaustive = FALSE, shuffle = TRUE)

    cs <- cand$summary
    pm_register(pm, !cs$has_excess_load, !cs$has_time_warp, !cs$has_excess_distance)

    iters_no_improve <- iters_no_improve + 1L
    if (feasible_cost(cand) < best_true) {
      best <- cand
      iters_no_improve <- 0L
      if (params$exhaustive_on_best) {
        refined <- run_local_search(ls, cand, ce, exhaustive = TRUE, shuffle = FALSE)
        if (isTRUE(refined$summary$is_feasible)) {
          best <- refined
          cand <- refined
        }
      }
      best_true <- feasible_cost(best)
    }

    cand_cost <- pen(cand)
    curr_cost <- pen(curr)
    late <- ring_peek()
    late_cost <- if (is.null(late)) pen(init) else pen(late)

    # LAHC (Burke & Bykov, 2017), com os dois reforços da seção 4.2.
    if (cand_cost < late_cost || cand_cost < curr_cost) {
      curr <- cand
      curr_cost <- cand_cost
    }
    if (curr_cost < late_cost || is.null(late)) ring_append(curr) else ring_skip()

    if (display) cli::cli_progress_update()
    if (isTRUE(stop(best_cost = best_true, feasible = is.finite(best_true)))) break
  }
  if (display) cli::cli_progress_done()

  list(
    best = best,
    cost = solution_objective(best),
    is_feasible = isTRUE(best$summary$is_feasible),
    iterations = iters,
    runtime = as.numeric(difftime(Sys.time(), start, units = "secs"))
  )
}
