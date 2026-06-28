# Instância VRPTW canônica: clientes em linha com janelas crescentes que forçam
# ordenação temporal. duration = distance (Euclidiano).
vrptw_model <- function() {
  clientes <- tibble::tibble(
    x        = c(10, 20, 30, 40, 50, 60),
    y        = 0,
    demand   = 10,
    tw_early = c(0, 30, 60, 90, 120, 150),
    tw_late  = c(50, 80, 110, 140, 170, 200),
    service  = 10
  )
  vrp_model() |>
    add_depot(x = 0, y = 0, tw_early = 0, tw_late = 500) |>
    add_clients(clientes) |>
    add_vehicle_type(num_available = 2, capacity = 60, tw_early = 0, tw_late = 500)
}

test_that("janelas de tempo são detectadas no ProblemData", {
  pd <- vrp_problem_data(vrptw_model())
  expect_true(pd$summary$has_time_windows)
})

test_that("o solver respeita as janelas de tempo (sem time warp)", {
  res <- vrp_solve(vrptw_model(), stop = max_iterations(500), seed = 1, display = FALSE)
  expect_true(res$is_feasible)
  expect_false(res$solution$summary$has_time_warp)
})

test_that("todo início de serviço cai dentro da janela do cliente", {
  m <- vrptw_model()
  res <- vrp_solve(m, stop = max_iterations(500), seed = 1, display = FALSE)
  rt <- routes(res)

  janelas <- m$clients[rt$client, c("tw_early", "tw_late")]
  expect_true(all(rt$start_service >= janelas$tw_early))
  expect_true(all(rt$start_service <= janelas$tw_late))
})

test_that("routes() expõe start_service e wait", {
  res <- vrp_solve(vrptw_model(), stop = max_iterations(100), seed = 1, display = FALSE)
  rt <- routes(res)
  expect_true(all(c("start_service", "wait") %in% names(rt)))
  expect_type(rt$start_service, "double")
  expect_true(all(rt$wait >= 0))
})

test_that("release_time é aceito como coluna de cliente", {
  clientes <- tibble::tibble(
    x = c(10, 20), y = 0, demand = 10, release_time = c(0, 100)
  )
  m <- vrp_model() |>
    add_depot(0, 0) |>
    add_clients(clientes) |>
    add_vehicle_type(num_available = 1, capacity = 50)
  expect_no_error(vrp_problem_data(m))
})
