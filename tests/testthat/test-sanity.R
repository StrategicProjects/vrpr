test_that("o toolchain C++20 está ativo", {
  expect_gte(vrpr_cpp_standard(), 20L)
  expect_true(vrpr_has_cxx20())
})

test_that("o binding cpp11 responde", {
  expect_type(vrpr_hello(), "character")
})
