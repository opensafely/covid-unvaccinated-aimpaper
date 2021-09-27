
## import command-line arguments
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  jcvi_group <- "02"
  model_type <- "unadj"
} else {
  jcvi_group <- args[[1]]
  model_type <- args[[2]]
}

## packages
library(tidyverse)
library(glue)

source(here::here("analysis", "lib", "model_postprocess.R"))
source(here::here("analysis", "lib", "sanitise_variables.R"))

cat(glue("#### run model ####\n"))
res <- list()
if  (model_type %in% "fadj") {
  res <- read_rds(here::here("output", "models", glue("model_{jcvi_group}_{model_type}_all.rds")))
} else {
  for (v in covs) {
    res[[v]] <- read_rds(here::here("output", "models", glue("model_{jcvi_group}_{model_type}_{v}.rds")))
  }
}

cat(glue("#### postprocess model output ####\n"))
table <- res %>% model_postprocess()
write_rds(table, here::here("output", "tables", glue("table_{jcvi_group}_{model_type}.rds")))
