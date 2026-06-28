# Blocos de construção da busca local (search/) do PyVRP.
#
# Estes são helpers internos: a face pública será `vrp_solve()`, que orquestra o
# laço ILS sobre eles (próximo passo do roadmap). Mantidos sem @export por ora.

# Cria o motor de busca local persistente (dados + RNG + perturbação + operadores).
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

# Roda a busca local sobre uma solução, devolvendo outra (idealmente melhor).
# exhaustive = TRUE  -> descida pura (sem perturbação), p.ex. solução inicial.
# exhaustive = FALSE -> uma iteração ILS (perturba + busca).
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
