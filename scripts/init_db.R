# scripts/init_db.R
library(DBI)
source("R/utils_db.R")
con <- connect_db()
cat("Migrating DB...\n")
migrate_db(con)
cat("Done.\n")
DBI::dbDisconnect(con)
