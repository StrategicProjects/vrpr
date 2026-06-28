test_that("the C++20 toolchain is active", {
  expect_gte(vrpr_cpp_standard(), 20L)
  expect_true(vrpr_has_cxx20())
})

test_that("the cpp11 binding responds", {
  expect_type(vrpr_hello(), "character")
})
