test_that("multiple add_vehicle_type calls create a heterogeneous fleet", {
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = c(10, 20), y = 0, demand = 10)) |>
    add_vehicle_type(num_available = 2, capacity = 50) |>
    add_vehicle_type(num_available = 1, capacity = 100, fixed_cost = 30)
  pd <- vrp_problem_data(m)
  expect_equal(pd$summary$num_vehicle_types, 2L)
  expect_equal(pd$summary$num_vehicles, 3L)
})

het_demand_model <- function(seed = 2, n = 16) {
  withr::with_seed(seed, {
    cl <- tibble::tibble(
      x = round(stats::runif(n, -40, 40)),
      y = round(stats::runif(n, -40, 40)),
      demand = sample(5:15, n, replace = TRUE)
    )
  })
  cl
}

test_that("the solver prefers the type with the lowest distance cost", {
  cl <- het_demand_model()
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 3, capacity = 50, unit_distance_cost = 1) |>
    add_vehicle_type(num_available = 3, capacity = 50, unit_distance_cost = 10)

  res <- vrp_solve(m, stop = max_iterations(500), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true(res$is_feasible)
  expect_setequal(rt$client, seq_len(nrow(cl)))
  # the expensive type (2) should not be used when the cheap one (1) suffices.
  expect_false(2L %in% rt$vehicle_type)
})

test_that("capacity forces the suitable vehicle type", {
  cl <- tibble::tibble(
    x = c(10, -10, 20, -20), y = c(10, -10, 20, -20), demand = 45
  )
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 1, capacity = 30) |> # small: cannot fit 45
    add_vehicle_type(num_available = 4, capacity = 50)    # large

  res <- vrp_solve(m, stop = max_iterations(300), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true(res$is_feasible)
  # Only type 2 (capacity 50) can serve clients with demand 45.
  expect_setequal(unique(rt$vehicle_type), 2L)
})
