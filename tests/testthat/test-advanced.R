# Variantes avançadas: coleta-e-entrega simultânea / backhaul e multi-trip.

test_that("a coleta (pickup) entra no modelo de carga", {
  # Entrega 20 + coleta 40 por cliente; capacidade 50. Os dois juntos numa rota
  # estouram a capacidade (a coleta acumula), então a solução é inviável.
  cl <- tibble::tibble(x = c(20, 40), y = 0, demand = 20, pickup = 40)
  pd <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = 2, capacity = 50) |>
    vrp_problem_data()

  juntos <- vrp_solution(pd, list(c(1, 2)))
  expect_true(juntos$summary$has_excess_load) # a coleta estoura a capacidade

  separados <- vrp_solution(pd, list(1, 2))
  expect_false(separados$summary$has_excess_load)
})

test_that("o solver respeita coleta-e-entrega simultânea", {
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

test_that("sem reload, um veículo não atende demanda acima da capacidade", {
  # 4 x 30 = 120 de demanda, 1 veículo de capacidade 50, 1 viagem.
  res <- vrp_solve(mt_model(), stop = max_iterations(300), seed = 1, display = FALSE)
  expect_false(res$is_feasible)
  expect_true(res$solution$summary$has_excess_load)
  expect_equal(res$solution$summary$num_trips, 1L)
})

test_that("com reload, um veículo faz múltiplas viagens (multi-trip)", {
  res <- vrp_solve(
    mt_model(reload_depots = 1, max_reloads = 10),
    stop = max_iterations(500), seed = 1, display = FALSE
  )
  expect_true(res$is_feasible)
  expect_true(res$solution$summary$is_complete)
  expect_gt(res$solution$summary$num_trips, 1L)
})

test_that("reload_depot fora do intervalo é rejeitado", {
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(tibble::tibble(x = 10, y = 0, demand = 5)) |>
    add_vehicle_type(num_available = 1, capacity = 50, reload_depots = 2)
  expect_error(vrp_problem_data(m), "1\\.\\.1")
})
