# R/payment_gateway_mock.R
# Simple mock payment gateway - in production you'd call an external provider

process_payment <- function(card_info, amount) {
  # card_info: list(number, exp_month, exp_year, cvc)
  # For demo: accept any card ending in even digit, decline odd
  last_digit <- as.integer(sub(".*([0-9])$", "\\1", as.character(card_info$number)))
  Sys.sleep(0.5)  # simulate network
  if (is.na(last_digit)) {
    return(list(success=FALSE, message="Invalid card"))
  }
  if ((last_digit %% 2) == 0) {
    return(list(success=TRUE, transaction_id = paste0("TX-", sample(100000:999999, 1))))
  } else {
    return(list(success=FALSE, message="Card declined"))
  }
}
