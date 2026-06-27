test_that("max_iterations para após N chamadas", {
  s <- max_iterations(3)
  expect_false(s())
  expect_false(s())
  expect_true(s())
})

test_that("no_improvement zera ao melhorar e para após n estagnações", {
  s <- no_improvement(2)
  expect_false(s(best_cost = 100))
  expect_false(s(best_cost = 90)) # melhorou -> zera
  expect_false(s(best_cost = 90)) # 1ª sem melhora
  expect_true(s(best_cost = 90))  # 2ª sem melhora -> para
})

test_that("first_feasible para na primeira solução viável", {
  s <- first_feasible()
  expect_false(s(feasible = FALSE))
  expect_true(s(feasible = TRUE))
})

test_that("max_runtime rejeita entradas inválidas", {
  expect_error(max_runtime(-1), "positivo")
})
