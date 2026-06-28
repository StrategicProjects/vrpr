# Prize-collecting: optional clients with a prize.
pc_model <- function() {
  clients <- tibble::tibble(
    x        = c(5, -5, 0, 100, 100, 100),
    y        = c(5, -5, 8, 10, 0, -10),
    demand   = 10,
    required = c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE),
    prize    = c(0, 0, 0, 5, 500, 5) # only the middle one (prize 500) offsets the detour
  )
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clients) |>
    add_vehicle_type(num_available = 4, capacity = 50)
}

test_that("low-prize optional clients are skipped; high-prize ones are visited", {
  res <- vrp_solve(pc_model(), stop = max_iterations(500), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true(all(1:3 %in% rt$client)) # required
  expect_true(5 %in% rt$client)        # optional with prize 500
  expect_false(any(c(4, 6) %in% rt$client)) # optionals with prize 5
})

test_that("uncollected_prizes and unvisited_clients are consistent", {
  res <- vrp_solve(pc_model(), stop = max_iterations(500), seed = 1, display = FALSE)
  expect_equal(res$solution$summary$uncollected_prizes, 10) # 5 + 5
  expect_setequal(unvisited_clients(res), c(4L, 6L))
})

test_that("the objective includes uncollected prizes", {
  res <- vrp_solve(pc_model(), stop = max_iterations(300), seed = 1, display = FALSE)
  s <- res$solution$summary
  esperado <- s$distance_cost + s$duration_cost + s$fixed_vehicle_cost + s$uncollected_prizes
  expect_equal(cost(res), esperado)
})

# ClientGroup: grupos mutuamente exclusivos.
group_model <- function(required = TRUE) {
  clients <- tibble::tibble(
    x = c(10, 20, 60, 120), y = 0, demand = 10,
    prize = c(0, 100, 100, 100)
  )
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clients) |>
    add_vehicle_type(num_available = 2, capacity = 50) |>
    add_client_group(clients = c(2, 3, 4), required = required)
}

test_that("required group: exactly one member is visited (the nearest)", {
  pd <- vrp_problem_data(group_model(required = TRUE))
  expect_equal(pd$summary$num_groups, 1L)

  res <- vrp_solve(group_model(required = TRUE), stop = max_iterations(500),
                   seed = 1, display = FALSE)
  in_group <- intersect(routes(res)$client, c(2, 3, 4))
  expect_length(in_group, 1L)
  expect_equal(in_group, 2L) # the nearest to the depot
  expect_true(res$solution$summary$is_complete)
})

test_that("optional low-prize group: no member visited", {
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = c(10, 200, 210), y = 0, demand = 10, prize = c(0, 1, 1))) |>
    add_vehicle_type(num_available = 2, capacity = 50) |>
    add_client_group(clients = c(2, 3), required = FALSE)
  res <- vrp_solve(m, stop = max_iterations(300), seed = 1, display = FALSE)
  expect_length(intersect(routes(res)$client, c(2, 3)), 0L)
})

test_that("group validations", {
  base <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = c(10, 20), y = 0, demand = 10)) |>
    add_vehicle_type(num_available = 1, capacity = 50)

  expect_error(add_client_group(base, clients = c(1, 1)), "duplicate")
  expect_error(
    vrp_problem_data(add_client_group(base, clients = c(1, 5))),
    "out of range"
  )
  dois <- base |>
    add_client_group(clients = 1) |>
    add_client_group(clients = 1)
  expect_error(vrp_problem_data(dois), "two groups")
})
