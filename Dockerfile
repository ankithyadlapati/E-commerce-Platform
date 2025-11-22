# Stage: base
FROM rocker/verse:4.2.3 AS base
RUN apt-get update && apt-get install -y libsqlite3-dev libssl-dev libcurl4-openssl-dev

WORKDIR /srv/app
COPY . /srv/app

RUN R -e "install.packages(c('DBI','RSQLite','plumber','jsonlite','shiny','shinydashboard','glue','dplyr','testthat'), repos='https://cloud.r-project.org')"

# Stage: api
FROM base AS api
EXPOSE 8000
CMD R -e "pr <- plumber::plumb('/srv/app/api/plumber.R'); pr$run(host='0.0.0.0', port=8000)"

# Stage: web (shiny)
FROM base AS web
EXPOSE 3838
CMD R -e "shiny::runApp('/srv/app/app', port=3838, host='0.0.0.0')"
