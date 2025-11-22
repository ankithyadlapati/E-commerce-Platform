#!/usr/bin/env bash
# convenience script to run local (requires R and packages)
Rscript -e "source('R/utils_db.R'); migrate_db()"
# run API in background
Rscript -e "pr <- plumber::plumb('api/plumber.R'); pr$run(host='0.0.0.0', port=8000)" &
# run shiny
Rscript -e "shiny::runApp('app', port=3838, host='0.0.0.0')"
