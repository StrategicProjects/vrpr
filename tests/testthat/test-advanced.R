# Advanced variants: simultaneous pickup and delivery / backhaul and multi-trip.

test_that("pickup is accounted for in the load model", {
  # Delivery 20 + pickup 40 per client; capacity 50. Both together in one route
  # exceed capacity (pickup accumulates), so the solution is infeasible.
  cl <- tibble::tibble(x = c(20, 40), y = 0, demand = 20, pickup = 40)
  pd <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 2, capacity = 50) |>
    vrp_problem_data()

  together <- vrp_solution(pd, list(c(1, 2)))
  expect_true(together$summary$has_excess_load) # pickup exceeds capacity

  separate <- vrp_solution(pd, list(1, 2))
  expect_false(separate$summary$has_excess_load)
})

test_that("the solver respects simultaneous pickup and delivery", {
  cl <- tibble::tibble(x = c(20, 40), y = 0, demand = 20, pickup = 40)
  res <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 2, capacity = 50) |>
    vrp_solve(stop = max_iterations(300), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_false(res$solution$summary$has_excess_load)
})

mt_model <- function(...) {
  cl <- tibble::tibble(x = c(10, -10, 0, 5), y = c(0, 0, 10, -10), demand = 30)
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 1, capacity = 50, ...)
}

test_that("without reload, one vehicle cannot serve demand above capacity", {
  # 4 x 30 = 120 demand, 1 vehicle of capacity 50, 1 trip.
  res <- vrp_solve(mt_model(), stop = max_iterations(300), seed = 1, display = FALSE)
  expect_false(res$is_feasible)
  expect_true(res$solution$summary$has_excess_load)
  expect_equal(res$solution$summary$num_trips, 1L)
})

test_that("with reload, one vehicle makes multiple trips (multi-trip)", {
  res <- vrp_solve(
    mt_model(reload_depots = 1, max_reloads = 10),
    stop = max_iterations(500), seed = 1, display = FALSE
  )
  expect_true(res$is_feasible)
  expect_true(res$solution$summary$is_complete)
  expect_gt(res$solution$summary$num_trips, 1L)
})

test_that("an out-of-range reload_depot is rejected", {
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = 10, y = 0, demand = 5)) |>
    add_vehicle_type(num_available = 1, capacity = 50, reload_depots = 2)
  expect_error(vrp_problem_data(m), "1\\.\\.1")
})
