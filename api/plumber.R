# api/plumber.R
library(plumber)
source("R/api_routes.R")
source("R/utils_db.R")
# ensure DB migrates on API boot in dev
migrate_db()

pr <- plumber$new()
pr <- register_routes(pr)
pr$run(host="0.0.0.0", port=8000)
