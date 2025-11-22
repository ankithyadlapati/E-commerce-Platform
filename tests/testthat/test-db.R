library(testthat)
source("R/utils_db.R")
source("R/models.R")

test_that("migrate and seed creates tables", {
  con <- connect_db()
  expect_true(migrate_db(con))
  # ensure products table exists
  res <- dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type='table' AND name='products';")
  expect_true(nrow(res) == 1)
  DBI::dbDisconnect(con)
})

test_that("create and list products", {
  con <- connect_db()
  # create product unique SKU
  sku <- paste0("TST-", as.integer(Sys.time()))
  create_product(sku, "Test Product", "desc", 1.23, stock = 10, con = con)
  p <- dbGetQuery(con, "SELECT * FROM products WHERE sku = ?", params = list(sku))
  expect_equal(nrow(p), 1)
  DBI::dbDisconnect(con)
})
