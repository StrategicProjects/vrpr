# Canonical VRPTW instance: clients on a line with increasing windows.
# temporal ordering. duration = distance (Euclidean).
vrptw_model <- function() {
  clients <- tibble::tibble(
    x        = c(10, 20, 30, 40, 50, 60),
    y        = 0,
    demand   = 10,
    tw_early = c(0, 30, 60, 90, 120, 150),
    tw_late  = c(50, 80, 110, 140, 170, 200),
    service  = 10
  )
  vrp_model() |>
    add_depot(x = 0, y = 0, tw_early = 0, tw_late = 500) |>
    add_clients(clients) |>
    add_vehicle_type(num_available = 2, capacity = 60, tw_early = 0, tw_late = 500)
}

test_that("time windows are detected in the ProblemData", {
  pd <- vrp_problem_data(vrptw_model())
  expect_true(pd$summary$has_time_windows)
})

test_that("the solver respects time windows (no time warp)", {
  res <- vrp_solve(vrptw_model(), stop = max_iterations(500), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_false(res$solution$summary$has_time_warp)
})

test_that("every service start falls within the client window", {
  m <- vrptw_model()
  res <- vrp_solve(m, stop = max_iterations(500), seed = 1, display = FALSE)
  rt <- routes(res)

  windows <- m$clients[rt$client, c("tw_early", "tw_late")]
  expect_true(all(rt$start_service >= windows$tw_early))
  expect_true(all(rt$start_service <= windows$tw_late))
})

test_that("routes() exposes start_service and wait", {
  res <- vrp_solve(vrptw_model(), stop = max_iterations(100), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true(all(c("start_service", "wait") %in% names(rt)))
  expect_type(rt$start_service, "double")
  expect_true(all(rt$wait >= 0))
})

test_that("release_time is accepted as a client column", {
  clients <- tibble::tibble(
    x = c(10, 20), y = 0, demand = 10, release_time = c(0, 100)
  )
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clients) |>
    add_vehicle_type(num_available = 1, capacity = 50)
  expect_no_error(vrp_problem_data(m))
})
