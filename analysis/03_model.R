# # # # # # # # # # # # # # # # # # # # #
# This script:
# imports processed data
# carries out further pre-processing for logistic regression
# applies the logistic regression mode
# carries out postprocessing of the results into a table
#
# The script should be run via an action in the project.yaml
# The script must be accompanied by two arguments:
# 1. JCVI group: 02, 09 or 11
# 2. the type of model: unadj, padj, fadj
# # # # # # # # # # # # # # # # # # # # #

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

## Create output directory
dir.create(here::here("output", "models"), showWarnings = FALSE, recursive=TRUE)

## load functions for preprocessing, modelling and postprocessing results
source(here::here("analysis", "lib", "model_preprocess.R"))
source(here::here("analysis", "lib", glue("model_{model_type}.R")))
source(here::here("analysis", "lib", "model_postprocess.R"))
source(here::here("analysis", "lib", "sanitise_variables.R"))

## for logging
cat(glue("#### JCVI group {jcvi_group} ####\n"))

cat(glue("#### preprocess data ####\n"))
data_preprocessed <- model_preprocess(g=jcvi_group)

## empty tibble for results
res <- list()
covs <- names(data_preprocessed)[!(names(data_preprocessed) %in% c("vax_12", "weight"))]

cat(glue("#### run model ####\n"))
if  (model_type %in% "fadj") {
  res <- data_preprocessed %>% model_fadj()
  write_rds(res, here::here("output", "models", glue("model_{jcvi_group}_{model_type}_all.rds")))
} else {
  for (v in covs) {
    if (model_type == "unadj") {
      res[[v]] <- data_preprocessed %>% model_unadj(v)
    } else if (model_type == "padj") {
      res[[v]] <- data_preprocessed %>% model_padj(v)
    } 
    write_rds(res[[v]], here::here("output", "models", glue("model_{jcvi_group}_{model_type}_{v}.rds")))
  }
}

cat(glue("#### postprocess model output ####\n"))
table <- res %>% model_postprocess()
write_rds(table, here::here("output", "tables", glue("xxx_{jcvi_group}_{model_type}.rds")))
