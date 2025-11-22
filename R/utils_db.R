# R/utils_db.R
library(DBI)
library(RSQLite)
library(glue)
library(dplyr)

get_db_path <- function() {
  # file-based SQLite DB placed at project root
  file.path(getwd(), "r-ecommerce.sqlite")
}

connect_db <- function() {
  path <- get_db_path()
  con <- dbConnect(RSQLite::SQLite(), path)
  # pragmatic PRAGMA for concurrency in small dev setup
  dbExecute(con, "PRAGMA foreign_keys = ON;")
  con
}

migrate_db <- function(con = NULL) {
  close_after <- FALSE
  if (is.null(con)) { con <- connect_db(); close_after <- TRUE }
  schema <- readLines(file.path(getwd(), "db", "schema.sql"))
  dbExecute(con, paste(schema, collapse = "\n"))
  if (file.exists(file.path(getwd(), "db", "seed.sql"))) {
    seed <- readLines(file.path(getwd(), "db", "seed.sql"))
    dbExecute(con, paste(seed, collapse = "\n"))
  }
  if (close_after) DBI::dbDisconnect(con)
  TRUE
}
