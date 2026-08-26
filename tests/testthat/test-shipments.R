# Pickup-and-delivery (shipments), new in PyVRP 0.14 / vrpr 0.2.0.

shipment_model <- function(n = 6, capacity = 10, num_available = 3, seed = 7) {
  withr::with_seed(seed, {
    sh <- tibble::tibble(
      pickup_x = round(stats::runif(n, -50, 50)),
      pickup_y = round(stats::runif(n, -50, 50)),
      delivery_x = round(stats::runif(n, -50, 50)),
      delivery_y = round(stats::runif(n, -50, 50)),
      amount = sample(1:5, n, replace = TRUE)
    )
  })
  vrp_model() |>
    add_depot(0, 0) |>
    add_shipments(sh) |>
    add_vehicle_type(num_available = num_available, capacity = capacity)
}

test_that("add_shipments validates and stores shipments", {
  m <- shipment_model(n = 4)
  expect_equal(nrow(m$shipments), 4L)
  expect_true(all(m$shipments$required))
  expect_error(
    add_shipments(vrp_model(), tibble::tibble(pickup_x = 1)),
    "needs the column"
  )
})

test_that("problem data counts shipments and their locations", {
  pd <- vrp_problem_data(shipment_model(n = 5))
  expect_equal(pd$summary$num_shipments, 5L)
  expect_equal(pd$summary$num_clients, 0L)
  # 1 depot + 2 locations per shipment.
  expect_equal(pd$summary$num_locations, 1L + 10L)
  expect_equal(sum(pd$locations$kind == "pickup"), 5L)
  expect_equal(sum(pd$locations$kind == "delivery"), 5L)
})

test_that("solving a pickup-and-delivery instance is feasible and complete", {
  res <- vrp_solve(shipment_model(), stop = max_iterations(300), seed = 42,
                   display = FALSE)
  expect_true(res$is_feasible)
  expect_equal(res$solution$summary$num_shipments, 6L)
  expect_equal(res$solution$summary$num_missing_shipments, 0L)

  r <- routes(res)
  # Every shipment appears exactly once as pickup and once as delivery.
  expect_setequal(r$shipment[r$activity == "pickup"], 1:6)
  expect_setequal(r$shipment[r$activity == "delivery"], 1:6)
  expect_true(all(is.na(r$client)))

  # Pickup precedes its delivery, in the same route and trip.
  for (s in 1:6) {
    pick <- r[r$activity == "pickup" & r$shipment == s, ]
    del <- r[r$activity == "delivery" & r$shipment == s, ]
    expect_equal(pick$route_id, del$route_id)
    expect_equal(pick$trip, del$trip)
    expect_lt(pick$position, del$position)
  }
})

test_that("clients and shipments can be mixed in one instance", {
  withr::with_seed(11, {
    cl <- tibble::tibble(
      x = round(stats::runif(8, -50, 50)),
      y = round(stats::runif(8, -50, 50)),
      demand = sample(3:8, 8, replace = TRUE)
    )
  })
  m <- shipment_model(n = 3, capacity = 30, num_available = 4) |>
    add_clients(cl)
  res <- vrp_solve(m, stop = max_iterations(400), seed = 42, display = FALSE)
  expect_true(res$is_feasible)

  r <- routes(res)
  expect_setequal(r$client[r$activity == "client"], 1:8)
  expect_setequal(r$shipment[r$activity == "pickup"], 1:3)
})

test_that("optional shipments may be left unplanned", {
  m <- shipment_model(n = 4, capacity = 10, num_available = 1)
  # Make all shipments optional with a tiny prize: serving them cannot pay off.
  m$shipments$required <- FALSE
  m$shipments$prize <- 1
  res <- vrp_solve(m, stop = max_iterations(200), seed = 42, display = FALSE)
  expect_true(res$is_feasible)

  u <- unplanned(res)
  served <- res$solution$summary$num_shipments
  expect_equal(served + length(unique(u$index[u$activity == "pickup"])), 4L)
})
