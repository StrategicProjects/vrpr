# Building blocks of PyVRP's local search (search/).
#
# These are internal helpers; the public face is `vrp_solve()`, which orchestrates
# the ILS loop over them. Kept unexported for now.

# Creates the persistent local-search engine (data + RNG + perturbation + operators).
new_local_search <- function(problem_data,
                             num_neighbours = 20L,
                             seed = 42L,
                             min_perturbations = 1L,
                             max_perturbations = 25L) {
  check_problem_data(problem_data)
  n_clients <- problem_data$summary$num_clients
  k <- min(as.integer(num_neighbours), max(1L, n_clients - 1L))

  ptr <- vrpr_local_search_create(
    problem_data$ptr,
    num_neighbours = k,
    seed = as.integer(seed),
    min_perturbations = as.integer(min_perturbations),
    max_perturbations = as.integer(max_perturbations)
  )
  structure(
    list(
      ptr = ptr,
      n_depots = problem_data$summary$num_depots,
      info = vrpr_local_search_info(ptr)
    ),
    class = "vrpr_local_search"
  )
}

# Runs local search on a solution, returning another (ideally better) one.
# exhaustive = TRUE  -> pure descent (no perturbation), e.g. the initial solution.
# exhaustive = FALSE -> one ILS iteration (perturb + search).
run_local_search <- function(ls, solution, cost_evaluator,
                             exhaustive = FALSE, shuffle = !exhaustive) {
  stopifnot(inherits(ls, "vrpr_local_search"))
  check_solution(solution)
  ptr <- vrpr_local_search_run(
    ls$ptr, solution$ptr, cost_evaluator$ptr,
    exhaustive = exhaustive, shuffle = shuffle
  )
  new_solution(ptr, ls$n_depots)
}
