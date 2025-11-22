# R/api_routes.R
library(plumber)
library(jsonlite)
source("R/models.R")
source("R/services.R")

# This file provides helper functions to register routes on a plumber router.

register_routes <- function(pr) {
  pr$handle("GET", "/products", function(req, res) {
    df <- list_products()
    res$body <- toJSON(df, auto_unbox = TRUE)
    res
  })

  pr$handle("GET", "/product/<sku>", function(req, res, sku) {
    p <- get_product_by_sku(sku)
    if (is.null(p)) {
      res$status <- 404
      return(list(error = "not_found"))
    }
    p
  })

  pr$handle("POST", "/orders", function(req, res) {
    body <- tryCatch(fromJSON(req$postBody), error = function(e) NULL)
    if (is.null(body)) {
      res$status <- 400
      return(list(error="invalid_json"))
    }
    # Expect body: { email: "...", items: [{sku, qty}], card: {number, exp_month, exp_year, cvc}}
    email <- body$email
    items <- body$items
    card <- body$card
    if (is.null(email) || is.null(items) || is.null(card)) {
      res$status <- 400
      return(list(error="missing_fields"))
    }
    result <- tryCatch({
      place_order(email, items, card)
    }, error = function(e) {
      res$status <- 400
      list(error = e$message)
    })
    result
  })

  pr$handle("GET", "/orders/<id>", function(req, res, id) {
    idn <- as.integer(id)
    if (is.na(idn)) { res$status <- 400; return(list(error="invalid_id")) }
    get_order(idn)
  })
  pr
}
