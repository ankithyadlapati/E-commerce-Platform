# R/services.R
library(jsonlite)
source("R/models.R")
source("R/payment_gateway_mock.R")

place_order <- function(customer_email, cart_items, card_info) {
  # cart_items: list of list(sku, qty)
  # run DB order creation
  order_id <- NULL
  tryCatch({
    order_id <- create_order(customer_email, cart_items)
  }, error = function(e) {
    stop(e$message)
  })

  # compute total for payment attempt (simple fetch)
  o <- get_order(order_id)
  total <- o$order$total

  # process payment
  pay <- process_payment(card_info, total)
  if (!isTRUE(pay$success)) {
    # update order status to FAILED
    con <- connect_db()
    dbExecute(con, "UPDATE orders SET status = ? WHERE id = ?", params = list("PAYMENT_FAILED", order_id))
    dbDisconnect(con)
    stop(pay$message)
  }
  # else mark order PAID
  con <- connect_db()
  dbExecute(con, "UPDATE orders SET status = ? WHERE id = ?", params = list("PAID", order_id))
  dbDisconnect(con)
  list(success = TRUE, order_id = order_id, transaction_id = pay$transaction_id)
}
