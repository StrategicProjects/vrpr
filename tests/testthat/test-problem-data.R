cvrp_model <- function(demand = c(10, 15, 8), capacity = 50, ...) {
  cl <- tibble::tibble(x = c(10, 25, 40), y = c(5, 30, 12), demand = demand, ...)
  vrp_model() |>
    add_depot(x = 0, y = 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 3, capacity = capacity)
}

test_that("ProblemData é construído com a contagem certa de locais", {
  pd <- vrp_problem_data(cvrp_model())
  expect_s3_class(pd, "vrpr_problem_data")
  expect_equal(pd$summary$num_clients, 3L)
  expect_equal(pd$summary$num_depots, 1L)
  expect_equal(pd$summary$num_locations, 4L)
  expect_equal(pd$summary$num_vehicles, 3L)
  expect_equal(pd$summary$num_load_dimensions, 1L)
})

test_that("a fronteira numérica rejeita medidas não inteiras", {
  expect_error(
    vrp_problem_data(cvrp_model(demand = c(10.5, 15, 8))),
    "inteiro"
  )
})

test_that("janelas de tempo finitas são detectadas; Inf é irrestrito", {
  com_janela <- vrp_problem_data(cvrp_model(tw_late = c(100, 100, 100)))
  expect_true(com_janela$summary$has_time_windows)

  sem_janela <- vrp_problem_data(cvrp_model(tw_late = Inf))
  expect_false(sem_janela$summary$has_time_windows)
})

test_that("matrizes com forma errada são rejeitadas no lado R", {
  expect_error(
    vrp_problem_data(cvrp_model(), distance = matrix(1, 2, 2)),
    "4x4"
  )
})

test_that("duration assume distance por padrão", {
  d <- matrix(c(0, 5, 5, 0), 2, 2)
  cl <- tibble::tibble(x = c(1), y = c(1), demand = 5)
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 1, capacity = 10)
  expect_no_error(vrp_problem_data(m, distance = d))
})
