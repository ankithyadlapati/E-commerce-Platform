# R/models.R
library(DBI)
library(dplyr)
source("R/utils_db.R")

create_product <- function(sku, name, description, price, stock = 0, con = NULL) {
  local_con <- FALSE
  if (is.null(con)) { con <- connect_db(); local_con <- TRUE }
  DBI::dbExecute(con, "INSERT INTO products(sku, name, description, price, stock) VALUES (?, ?, ?, ?, ?)",
                 params = list(sku, name, description, price, as.integer(stock)))
  if (local_con) DBI::dbDisconnect(con)
  TRUE
}

list_products <- function(con = NULL) {
  if (is.null(con)) con <- connect_db()
  df <- dbGetQuery(con, "SELECT * FROM products ORDER BY id")
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  df
}

get_product_by_sku <- function(sku, con = NULL) {
  if (is.null(con)) con <- connect_db()
  res <- dbGetQuery(con, "SELECT * FROM products WHERE sku = ?", params = list(sku))
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  if (nrow(res) == 0) return(NULL)
  res[1,]
}

reduce_stock <- function(product_id, qty, con = NULL) {
  if (is.null(con)) con <- connect_db()
  dbExecute(con, "UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?", params = list(as.integer(qty), as.integer(product_id), as.integer(qty)))
  affected <- dbGetQuery(con, "SELECT changes() AS changes")$changes
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  affected > 0
}

create_user_if_missing <- function(email, name = NULL, con = NULL) {
  if (is.null(con)) con <- connect_db()
  existing <- dbGetQuery(con, "SELECT * FROM users WHERE email = ?", params = list(email))
  if (nrow(existing) > 0) {
    if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
    return(existing[1, ])
  }
  dbExecute(con, "INSERT INTO users(email, name) VALUES (?, ?)", params = list(email, name))
  new <- dbGetQuery(con, "SELECT * FROM users WHERE email = ?", params = list(email))
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  new[1,]
}

create_order <- function(user_email, items, con = NULL) {
  # items: list of lists: list(list(sku='SKU-001', qty=2), ...)
  local_con <- FALSE
  if (is.null(con)) { con <- connect_db(); local_con <- TRUE }
  DBI::dbBegin(con)
  on.exit({
    if (DBI::dbGetException(con)$errorNum != 0) DBI::dbRollback(con)
  }, add = TRUE)

  user <- create_user_if_missing(user_email, con = con)
  total <- 0
  # compute total, verify stock
  for (it in items) {
    p <- dbGetQuery(con, "SELECT * FROM products WHERE sku = ?", params = list(it$sku))
    if (nrow(p) == 0) stop(glue::glue("Product {it$sku} not found"))
    if (p$stock < it$qty) stop(glue::glue("Not enough stock for {it$sku}"))
    total <- total + (p$price * it$qty)
  }
  # insert order
  dbExecute(con, "INSERT INTO orders(user_id, total, status) VALUES (?, ?, ?)",
            params = list(as.integer(user$id), total, "RECEIVED"))
  order_id <- dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  for (it in items) {
    p <- dbGetQuery(con, "SELECT * FROM products WHERE sku = ?", params = list(it$sku))
    dbExecute(con, "INSERT INTO order_lines(order_id, product_id, quantity, price) VALUES (?,?,?,?)",
              params = list(as.integer(order_id), as.integer(p$id), as.integer(it$qty), p$price))
    # reduce stock
    dbExecute(con, "UPDATE products SET stock = stock - ? WHERE id = ?", params = list(as.integer(it$qty), as.integer(p$id)))
  }
  DBI::dbCommit(con)
  if (local_con) DBI::dbDisconnect(con)
  order_id
}

get_order <- function(order_id, con = NULL) {
  if (is.null(con)) con <- connect_db()
  o <- dbGetQuery(con, "SELECT * FROM orders WHERE id = ?", params = list(order_id))
  lines <- dbGetQuery(con, "SELECT ol.*, p.sku, p.name FROM order_lines ol JOIN products p ON ol.product_id = p.id WHERE ol.order_id = ?", params = list(order_id))
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  list(order=o, lines=lines)
}
