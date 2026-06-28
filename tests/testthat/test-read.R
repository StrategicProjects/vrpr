test_that("read_vrplib reads a CVRP instance", {
  path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
  skip_if(path == "")
  m <- read_vrplib(path)

  expect_s3_class(m, "vrpr_model")
  expect_equal(nrow(m$depots), 1L)
  expect_equal(nrow(m$clients), 5L)
  expect_equal(m$vehicle_types$capacity, 30)
  expect_equal(m$vehicle_types$num_available, 2L) # from the -k2 suffix
})

test_that("the parsed VRPLIB instance solves", {
  path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
  skip_if(path == "")
  res <- read_vrplib(path) |>
    vrp_solve(stop = max_iterations(200), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_equal(nrow(routes(res)), 5L)
})

test_that("num_vehicles overrides the default", {
  path <- system.file("extdata", "sample-n6-k2.vrp", package = "vrpr")
  skip_if(path == "")
  m <- read_vrplib(path, num_vehicles = 5)
  expect_equal(m$vehicle_types$num_available, 5L)
})

test_that("read_solomon reads a VRPTW instance", {
  path <- system.file("extdata", "sample-solomon.txt", package = "vrpr")
  skip_if(path == "")
  m <- read_solomon(path)

  expect_s3_class(m, "vrpr_model")
  expect_equal(nrow(m$depots), 1L)
  expect_equal(nrow(m$clients), 4L)
  expect_equal(m$vehicle_types$capacity, 50)
  expect_equal(m$vehicle_types$num_available, 3L)
  # the time windows should have been read.
  expect_true(any(m$clients$tw_late < Inf))
})

test_that("the parsed Solomon instance solves respecting the windows", {
  path <- system.file("extdata", "sample-solomon.txt", package = "vrpr")
  skip_if(path == "")
  res <- read_solomon(path) |>
    vrp_solve(stop = max_iterations(300), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_false(res$solution$summary$has_time_warp)
})
