small_result <- function() {
  cl <- tibble::tibble(x = c(10, -10, 0, 5), y = c(0, 0, 10, -10), demand = 10)
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 2, capacity = 30) |>
    vrp_solve(stop = max_iterations(100), seed = 1, display = FALSE)
}

test_that("plot.vrpr_result returns a ggplot", {
  skip_if_not_installed("ggplot2")
  p <- plot(small_result())
  expect_s3_class(p, "ggplot")
})

test_that("plot.vrpr_model returns a ggplot", {
  skip_if_not_installed("ggplot2")
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = c(1, 2), y = c(1, 2), demand = 5)) |>
    add_vehicle_type(num_available = 1, capacity = 30)
  expect_s3_class(plot(m), "ggplot")
})

test_that("route_paths closes each route at the depot", {
  res <- small_result()
  locs <- res$problem_data$locations
  depots <- locs[locs$kind == "depot", ]
  clients <- locs[locs$kind == "client", ]
  rt <- routes(res)

  paths <- route_paths(rt, depots, clients)
  # Each route: 1 depot + k clients + 1 depot = k + 2 points.
  por_rota <- tapply(rt$client, rt$route_id, length)
  esperado <- sum(por_rota + 2L)
  expect_equal(nrow(paths), esperado)
  # The first and last point of each route coincide (depot).
  for (rid in unique(paths$route_id)) {
    pr <- paths[paths$route_id == rid, ]
    expect_equal(pr[1, c("x", "y")], pr[nrow(pr), c("x", "y")])
  }
})
