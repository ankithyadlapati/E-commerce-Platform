# app/app.R
library(shiny)
library(shinydashboard)
source("R/models.R")
source("R/services.R")
source("R/utils_db.R")

# ensure DB exists for app runtime
migrate_db()

ui <- dashboardPage(
  dashboardHeader(title = "R E-Commerce"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Storefront", tabName = "store", icon = icon("store")),
      menuItem("Cart", tabName = "cart", icon = icon("shopping-cart")),
      menuItem("Orders", tabName = "orders", icon = icon("clipboard")),
      menuItem("Admin", tabName = "admin", icon = icon("tools"))
    )
  ),
  dashboardBody(
    tags$head(tags$link(rel="stylesheet", type="text/css", href="../inst/www/styles.css")),
    tabItems(
      tabItem(tabName = "store",
              fluidRow(
                box(title = "Products", width = 12, uiOutput("product_list"))
              )
      ),
      tabItem(tabName = "cart",
              fluidRow(
                box(title = "Your Cart", width = 8, tableOutput("cart_table")),
                box(title = "Checkout", width = 4,
                    textInput("email", "Email"),
                    textInput("card_number", "Card Number"),
                    numericInput("card_month", "Exp Month", 1, 1, 12),
                    numericInput("card_year", "Exp Year", 2025, 2023, 2030),
                    textInput("card_cvc", "CVC"),
                    actionButton("checkout", "Place Order")
                )
              )
      ),
      tabItem(tabName = "orders",
              fluidRow(box(width = 12, tableOutput("orders_table")))
      ),
      tabItem(tabName = "admin",
              fluidRow(
                box(title = "Admin - Products", width = 6,
                    textInput("admin_sku", "SKU"),
                    textInput("admin_name", "Name"),
                    numericInput("admin_price", "Price", 0, 0, 10000),
                    numericInput("admin_stock", "Stock", 1, 0, 100000),
                    actionButton("admin_add", "Add Product")
                ),
                box(title = "Analytics", width = 6, verbatimTextOutput("analytics"))
              )
      )
    )
  )
)

server <- function(input, output, session) {
  # simple reactive cart stored in session
  cart <- reactiveVal(data.frame(sku=character(), qty=integer(), stringsAsFactors = FALSE))

  observeEvent(input$admin_add, {
    create_product(input$admin_sku, input$admin_name, "", input$admin_price, input$admin_stock)
    showNotification("Product added", type="message")
  })

  output$product_list <- renderUI({
    df <- list_products()
    if (nrow(df)==0) return(tags$p("No products"))
    lapply(seq_len(nrow(df)), function(i) {
      row <- df[i,]
      fluidRow(
        column(8, strong(row$name), p(row$description), p(glue::glue("Price: ${row$price} | Stock: {row$stock}"))),
        column(4, numericInput(paste0("qty_", row$sku), "Qty", 1, 1, 100),
               actionButton(paste0("add_", row$sku), "Add to cart"))
      )
    })
  })

  # dynamic add handlers
  observe({
    df <- list_products()
    lapply(seq_len(nrow(df)), function(i) {
      sku <- df$sku[i]
      add_id <- paste0("add_", sku)
      qty_id <- paste0("qty_", sku)
      observeEvent(input[[add_id]], {
        q <- input[[qty_id]]
        cur <- cart()
        if (sku %in% cur$sku) {
          cur$qty[cur$sku == sku] <- cur$qty[cur$sku == sku] + q
        } else {
          cur <- rbind(cur, data.frame(sku=sku, qty=q, stringsAsFactors = FALSE))
        }
        cart(cur)
        showNotification(glue::glue("{q} x {sku} added to cart"), type="message")
      }, ignoreInit = TRUE)
    })
  })

  output$cart_table <- renderTable({
    cart()
  }, rownames = TRUE)

  observeEvent(input$checkout, {
    items <- lapply(seq_len(nrow(cart())), function(i) {
      list(sku = cart()$sku[i], qty = cart()$qty[i])
    })
    card <- list(number=input$card_number, exp_month=input$card_month, exp_year=input$card_year, cvc=input$card_cvc)
    res <- tryCatch({
      place_order(input$email, items, card)
    }, error = function(e) { e })
    if (inherits(res, "error")) {
      showNotification(res$message, type="error")
    } else {
      showModal(modalDialog(title="Order Placed",
                            paste("Order ID:", res$order_id, "Transaction:", res$transaction_id)))
      cart(data.frame(sku=character(), qty=integer(), stringsAsFactors = FALSE))
    }
  })

  output$orders_table <- renderTable({
    con <- connect_db()
    df <- dbGetQuery(con, "SELECT o.id, u.email, o.total, o.status, o.created_at FROM orders o LEFT JOIN users u ON o.user_id = u.id ORDER BY o.created_at DESC")
    DBI::dbDisconnect(con)
    df
  })

  output$analytics <- renderPrint({
    df <- list_products()
    cat("Total SKUs:", nrow(df), "\n")
    cat("Total stock:", sum(df$stock), "\n")
    cat("Top SKUs by stock:\n")
    print(df %>% arrange(desc(stock)) %>% head(5))
  })
}

shinyApp(ui, server)
