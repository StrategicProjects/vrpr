# MDVRP: two distant depots, clients clustered around each one.
mdvrp_model <- function() {
  clients <- tibble::tibble(
    x = c(-55, -45, -50, -48, 55, 45, 50, 52),
    y = c(5, -5, 10, -8, 5, -5, 8, -6),
    demand = 10
  )
  vrp_model() |>
    add_depot(x = -50, y = 0) |> # depot 1
    add_depot(x = 50, y = 0) |>  # depot 2
    add_clients(clients) |>
    add_vehicle_type(num_available = 3, capacity = 50, depot = 1) |>
    add_vehicle_type(num_available = 3, capacity = 50, depot = 2)
}

test_that("multiple add_depot calls create a multi-depot problem", {
  pd <- vrp_problem_data(mdvrp_model())
  expect_equal(pd$summary$num_depots, 2L)
  expect_equal(pd$summary$num_vehicle_types, 2L)
})

test_that("each client is served by the nearest depot", {
  res <- vrp_solve(mdvrp_model(), stop = max_iterations(500), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true(res$is_feasible)
  expect_setequal(rt$client, 1:8)
  # clients 1-4 (left) at depot 1; 5-8 (right) at depot 2.
  expect_true(all(rt$depot[rt$client <= 4] == 1L))
  expect_true(all(rt$depot[rt$client >= 5] == 2L))
})

test_that("routes() exposes the depot column (1-based)", {
  res <- vrp_solve(mdvrp_model(), stop = max_iterations(100), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true("depot" %in% names(rt))
  expect_setequal(unique(rt$depot), c(1L, 2L))
})

test_that("an out-of-range depot index is rejected", {
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = 10, y = 0, demand = 5)) |>
    add_vehicle_type(num_available = 1, capacity = 50, depot = 3) # only 1 depot exists
  expect_error(vrp_problem_data(m), "1\\.\\.1")
})

test_that("the single-depot case remains the default", {
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = c(10, 20), y = 0, demand = 10)) |>
    add_vehicle_type(num_available = 2, capacity = 50)
  res <- vrp_solve(m, stop = max_iterations(100), seed = 1, display = FALSE)
  expect_true(all(routes(res)$depot == 1L))
})
