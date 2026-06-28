cluster_cvrp <- function(n = 12, seed = 1) {
  withr::with_seed(seed, {
    clientes <- tibble::tibble(
      x = round(stats::runif(n, -50, 50)),
      y = round(stats::runif(n, -50, 50)),
      demand = 10
    )
  })
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clientes) |>
    add_vehicle_type(num_available = 4, capacity = 40) |>
    vrp_problem_data()
}

test_that("o motor registra operadores de nó e de rota", {
  ls <- new_local_search(cluster_cvrp(), seed = 42)
  expect_gt(ls$info$num_node_operators, 0L)
  # ao menos um operador deve estar ativo
  expect_gte(ls$info$num_node_operators + ls$info$num_route_operators, 1L)
})

test_that("a busca local não piora a solução (descida pura)", {
  pd <- cluster_cvrp()
  ce <- vrp_cost_evaluator(1000, 1000, 1000)
  ls <- new_local_search(pd, seed = 42)

  inicial <- vrp_random_solution(pd, seed = 42)
  melhor <- run_local_search(ls, inicial, ce, exhaustive = TRUE)

  c0 <- as.numeric(solution_cost(inicial, ce))
  c1 <- as.numeric(solution_cost(melhor, ce))
  expect_lte(c1, c0)
  expect_true(melhor$summary$is_feasible)
})

test_that("a busca local é reprodutível por seed", {
  pd <- cluster_cvrp()
  ce <- vrp_cost_evaluator(1000, 1000, 1000)

  run_once <- function() {
    ls <- new_local_search(pd, seed = 7)
    cur <- run_local_search(ls, vrp_random_solution(pd, seed = 7), ce, exhaustive = TRUE)
    for (i in 1:10) {
      cur <- run_local_search(ls, cur, ce, exhaustive = FALSE, shuffle = TRUE)
    }
    as.numeric(solution_cost(cur, ce))
  }
  expect_equal(run_once(), run_once())
})
