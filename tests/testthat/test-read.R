test_that("read_vrplib lê uma instância CVRP", {
  path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
  skip_if(path == "")
  m <- read_vrplib(path)

  expect_s3_class(m, "vrpr_model")
  expect_equal(nrow(m$depots), 1L)
  expect_equal(nrow(m$clients), 5L)
  expect_equal(m$vehicle_types$capacity, 30)
  expect_equal(m$vehicle_types$num_available, 2L) # do sufixo -k2
})

test_that("a instância VRPLIB lida resolve", {
  path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
  skip_if(path == "")
  res <- read_vrplib(path) |>
    vrp_solve(stop = max_iterations(200), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_equal(nrow(routes(res)), 5L)
})

test_that("num_vehicles sobrescreve o padrão", {
  path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
  skip_if(path == "")
  m <- read_vrplib(path, num_vehicles = 5)
  expect_equal(m$vehicle_types$num_available, 5L)
})

test_that("read_solomon lê uma instância VRPTW", {
  path <- system.file("extdata", "sample-solomon.txt", package = "vrpr")
  skip_if(path == "")
  m <- read_solomon(path)

  expect_s3_class(m, "vrpr_model")
  expect_equal(nrow(m$depots), 1L)
  expect_equal(nrow(m$clients), 4L)
  expect_equal(m$vehicle_types$capacity, 50)
  expect_equal(m$vehicle_types$num_available, 3L)
  # As janelas de tempo devem ter sido lidas.
  expect_true(any(m$clients$tw_late < Inf))
})

test_that("a instância Solomon lida resolve respeitando as janelas", {
  path <- system.file("extdata", "sample-solomon.txt", package = "vrpr")
  skip_if(path == "")
  res <- read_solomon(path) |>
    vrp_solve(stop = max_iterations(300), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_false(res$solution$summary$has_time_warp)
})
