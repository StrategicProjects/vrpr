square_cvrp <- function(capacity = 50, demand = 20) {
  clients <- tibble::tibble(
    x = c(10, 10, -10, -10), y = c(10, -10, 10, -10),
    demand = demand
  )
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clients) |>
    add_vehicle_type(num_available = 2, capacity = capacity) |>
    vrp_problem_data()
}

test_that("the solution is built and the distance checks out", {
  pd <- square_cvrp()
  sol <- vrp_solution(pd, list(c(1, 2), c(3, 4)))
  expect_s3_class(sol, "vrpr_solution")
  expect_equal(sol$summary$num_routes, 2L)
  expect_equal(sol$summary$num_clients, 4L)
  # 2 symmetric routes of 14 + 20 + 14 = 48 each.
  expect_equal(sol$summary$distance, 96)
  expect_true(sol$summary$is_feasible)
})

test_that("for a feasible solution, cost == distance (unit CVRP)", {
  pd <- square_cvrp()
  sol <- vrp_solution(pd, list(c(1, 2), c(3, 4)))
  custo <- solution_cost(sol, vrp_cost_evaluator(100, 100, 100))
  expect_equal(as.numeric(custo), 96)
  expect_true(attr(custo, "feasible"))
})

test_that("excess load makes the solution infeasible", {
  pd <- square_cvrp(capacity = 50, demand = 20)
  bad <- vrp_solution(pd, list(c(1, 2, 3, 4))) # 80 > 50
  expect_false(bad$summary$is_feasible)
  expect_true(bad$summary$has_excess_load)
})

test_that("routes() returns a long tibble with 1-based client numbers", {
  pd <- square_cvrp()
  sol <- vrp_solution(pd, list(c(1, 2), c(3, 4)))
  r <- routes(sol)
  expect_s3_class(r, "tbl_df")
  expect_equal(nrow(r), 4L)
  expect_setequal(r$client, 1:4)
  expect_equal(sort(unique(r$route_id)), c(1L, 2L))
})

test_that("vrp_random_solution is reproducible by seed", {
  pd <- square_cvrp()
  a <- vrp_random_solution(pd, seed = 7)
  b <- vrp_random_solution(pd, seed = 7)
  expect_equal(a$summary$distance, b$summary$distance)
})

test_that("negative penalties are rejected", {
  expect_error(vrp_cost_evaluator(load_penalties = -1), "negative")
})
