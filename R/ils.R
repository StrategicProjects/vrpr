# Iterated Local Search loop (faithful port of PyVRP's IteratedLocalSearch.py).
#
# Uses Late Acceptance Hill-Climbing (Burke & Bykov, 2017): accepts the candidate
# if it improves on the cost from `history_length` iterations ago OR the current
# cost. After `num_iters_no_improvement` iterations without improvement, it
# restarts from the best. When a new best is found, it runs an exhaustive search
# (no perturbation) to refine it. Penalties are adjusted adaptively between
# iterations.

#' ILS solver parameters
#'
#' @param num_neighbours Granular neighbourhood size (k neighbours per client).
#' @param min_perturbations,max_perturbations Range of perturbations per iteration.
#' @param init_load,init_tw,init_dist Initial penalties.
#' @param history_length Length of the late-acceptance history (> 0). Default
#'   300, as in PyVRP.
#' @param num_iters_no_improvement Iterations without improvement before
#'   restarting from the best.
#' @param exhaustive_on_best Refine each new best with an exhaustive search?
#' @return A list of parameters.
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

# Objective (cost without infeasibility penalties): route costs + uncollected
# prizes. For instances without optional clients, uncollected_prizes = 0.
solution_objective <- function(sol) {
  s <- sol$summary
  s$distance_cost + s$duration_cost + s$fixed_vehicle_cost + s$uncollected_prizes
}

# "True" cost in the style of PyVRP's CostEvaluator::cost: the objective if
# feasible, otherwise infinite (so infeasible solutions never become the best).
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

  # Ring buffer of solutions for the late acceptance.
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

  # Penalised cost of a solution under the current evaluator.
  pen <- function(sol) as.numeric(solution_cost(sol, ce))

  iters <- 0L
  iters_no_improve <- 0L
  best_true <- feasible_cost(best)

  if (display) {
    cli::cli_progress_bar(
      format = paste0(
        "{cli::pb_spin} ILS · iteration {iters} · ",
        "best {if (is.finite(best_true)) round(best_true) else '—'} · ",
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

    # LAHC (Burke & Bykov, 2017), with both enhancements from section 4.2.
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
