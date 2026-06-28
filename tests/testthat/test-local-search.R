cluster_cvrp <- function(n = 12, seed = 1) {
  withr::with_seed(seed, {
    clients <- tibble::tibble(
      x = round(stats::runif(n, -50, 50)),
      y = round(stats::runif(n, -50, 50)),
      demand = 10
    )
  })
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clients) |>
    add_vehicle_type(num_available = 4, capacity = 40) |>
    vrp_problem_data()
}

test_that("the engine registers node and route operators", {
  ls <- new_local_search(cluster_cvrp(), seed = 42)
  expect_gt(ls$info$num_node_operators, 0L)
  # at least one operator should be active
  expect_gte(ls$info$num_node_operators + ls$info$num_route_operators, 1L)
})

test_that("local search does not worsen the solution (pure descent)", {
  pd <- cluster_cvrp()
  ce <- vrp_cost_evaluator(1000, 1000, 1000)
  ls <- new_local_search(pd, seed = 42)

  initial <- vrp_random_solution(pd, seed = 42)
  best <- run_local_search(ls, initial, ce, exhaustive = TRUE)

  c0 <- as.numeric(solution_cost(initial, ce))
  c1 <- as.numeric(solution_cost(best, ce))
  expect_lte(c1, c0)
  expect_true(best$summary$is_feasible)
})

test_that("local search is reproducible by seed", {
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
