solve_model <- function(n = 15, capacity = 50, num_available = 5, seed = 1) {
  withr::with_seed(seed, {
    cl <- tibble::tibble(
      x = round(stats::runif(n, -50, 50)),
      y = round(stats::runif(n, -50, 50)),
      demand = sample(5:15, n, replace = TRUE)
    )
  })
  vrp_model() |>
    add_depot(0, 0) |>
    add_clients(cl) |>
    add_vehicle_type(num_available = num_available, capacity = capacity)
}

test_that("vrp_solve devolve um resultado viável para um CVRP folgado", {
  res <- vrp_solve(solve_model(), stop = max_iterations(200), seed = 42, display = FALSE)
  expect_s3_class(res, "vrpr_result")
  expect_true(res$is_feasible)
  expect_true(is.finite(cost(res)))
  expect_gt(res$solution$summary$num_routes, 0L)
})

test_that("todo cliente é visitado exatamente uma vez", {
  res <- vrp_solve(solve_model(n = 15), stop = max_iterations(200), seed = 42, display = FALSE)
  r <- routes(res)
  expect_equal(nrow(r), 15L)
  expect_setequal(r$client, 1:15)
})

test_that("o solver é reprodutível por seed", {
  a <- vrp_solve(solve_model(), stop = max_iterations(150), seed = 7, display = FALSE)
  b <- vrp_solve(solve_model(), stop = max_iterations(150), seed = 7, display = FALSE)
  expect_equal(cost(a), cost(b))
  expect_equal(routes(a), routes(b))
})

test_that("mais iterações não pioram a melhor solução", {
  curto <- vrp_solve(solve_model(), stop = max_iterations(30), seed = 1, display = FALSE)
  longo <- vrp_solve(solve_model(), stop = max_iterations(400), seed = 1, display = FALSE)
  expect_lte(cost(longo), cost(curto))
})

test_that("vrp_solve aceita um problem_data já montado", {
  pd <- vrp_problem_data(solve_model())
  res <- vrp_solve(pd, stop = max_iterations(100), seed = 1, display = FALSE)
  expect_s3_class(res, "vrpr_result")
})

test_that("summary() devolve um tibble de uma linha", {
  res <- vrp_solve(solve_model(), stop = max_iterations(100), seed = 1, display = FALSE)
  s <- summary(res)
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 1L)
  expect_true(all(c("cost", "is_feasible", "num_routes", "runtime") %in% names(s)))
})

test_that("stop inválido é rejeitado", {
  expect_error(
    vrp_solve(solve_model(), stop = "10 segundos", display = FALSE),
    "critério de parada"
  )
})
